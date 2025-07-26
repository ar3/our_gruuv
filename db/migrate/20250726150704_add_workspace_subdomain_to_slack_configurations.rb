class AddWorkspaceSubdomainToSlackConfigurations < ActiveRecord::Migration[8.0]
  def change
    add_column :slack_configurations, :workspace_subdomain, :string
  end
end
