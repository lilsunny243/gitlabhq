# frozen_string_literal: true

class CreateRemoteDevelopmentAgentConfigAgentForeignKey < Gitlab::Database::Migration[2.1]
  disable_ddl_transaction!

  def up
    add_concurrent_foreign_key :remote_development_agent_configs,
      :cluster_agents, column: :cluster_agent_id, on_delete: :cascade
  end

  def down
    with_lock_retries do
      remove_foreign_key :remote_development_agent_configs, column: :cluster_agent_id
    end
  end
end
