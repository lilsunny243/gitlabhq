# frozen_string_literal: true

module Projects
  class UpdateRepositoryStorageService
    include UpdateRepositoryStorageMethods

    delegate :project, to: :repository_storage_move

    private

    def track_repository(_destination_storage_name)
      # Connect project to pool repository from the new shard
      project.swap_pool_repository!

      # Connect project to the repository from the new shard
      project.track_project_repository

      # Link repository from the new shard to pool repository from the new shard
      project.link_pool_repository if replicate_object_pool_on_move_ff_enabled?
    end

    def mirror_repositories
      if project.repository_exists?
        mirror_repository(type: Gitlab::GlRepository::PROJECT)
      end

      if project.wiki.repository_exists?
        mirror_repository(type: Gitlab::GlRepository::WIKI)
      end

      if project.design_repository.exists?
        mirror_repository(type: ::Gitlab::GlRepository::DESIGN)
      end
    end

    def mirror_object_pool(destination_storage_name)
      return unless replicate_object_pool_on_move_ff_enabled?
      return unless project.repository_exists?

      pool_repository = project.pool_repository
      return unless pool_repository

      # If pool repository already exists, then we will link the moved project repository to it
      return if pool_repository_exists_for?(shard_name: destination_storage_name, pool_repository: pool_repository)

      target_pool_repository = create_pool_repository_for!(
        shard_name: destination_storage_name,
        pool_repository: pool_repository
      )

      checksum, new_checksum = replicate_object_pool_repository(from: pool_repository, to: target_pool_repository)

      if checksum != new_checksum
        raise Error,
          format(s_('UpdateRepositoryStorage|Failed to verify %{type} repository checksum from %{old} to %{new}'),
            type: 'object_pool', old: checksum, new: new_checksum)
      end
    end

    def remove_old_paths
      super

      if project.wiki.repository_exists?
        Gitlab::Git::Repository.new(
          source_storage_name,
          "#{project.wiki.disk_path}.git",
          nil,
          nil
        ).remove
      end

      if project.design_repository.exists?
        Gitlab::Git::Repository.new(
          source_storage_name,
          "#{project.design_repository.disk_path}.git",
          nil,
          nil
        ).remove
      end
    end

    def pool_repository_exists_for?(shard_name:, pool_repository:)
      PoolRepository.by_disk_path_and_shard_name(
        pool_repository.disk_path,
        shard_name
      ).exists?
    end

    def create_pool_repository_for!(shard_name:, pool_repository:)
      # Set state `ready` because we manually replicate object pool
      PoolRepository.create!(
        shard: Shard.by_name(shard_name),
        source_project: pool_repository.source_project,
        disk_path: pool_repository.disk_path,
        state: 'ready'
      )
    end

    def replicate_object_pool_repository(from:, to:)
      old_object_pool = from.object_pool
      new_object_pool = to.object_pool

      checksum = old_object_pool.repository.checksum

      new_object_pool.repository.replicate(old_object_pool.repository)

      new_checksum = new_object_pool.repository.checksum

      [checksum, new_checksum]
    end

    def replicate_object_pool_on_move_ff_enabled?
      Feature.enabled?(:replicate_object_pool_on_move, project)
    end
  end
end
