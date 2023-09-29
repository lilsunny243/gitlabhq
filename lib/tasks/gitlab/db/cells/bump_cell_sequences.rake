# frozen_string_literal: true

namespace :gitlab do
  namespace :db do
    namespace :cells do
      desc 'Bump sequences for cell-local tables on the cells database'
      task :bump_cell_sequences, [:increase_by] => :environment do |_t, args|
        # We do not want to run this on production environment, even accidentally.
        unless Gitlab.dev_or_test_env?
          puts 'This rake task cannot be run in production environment'.color(:red)
          exit 1
        end

        increase_by = args.increase_by.to_i
        if increase_by < 1
          puts 'Please specify a positive integer `increase_by` value'.color(:red)
          puts 'Example: rake gitlab:db:cells:bump_cell_sequences[100000]'.color(:green)
          exit 1
        end

        Gitlab::Database::BumpSequences.new(:gitlab_main_cell, increase_by).execute
      end
    end
  end
end
