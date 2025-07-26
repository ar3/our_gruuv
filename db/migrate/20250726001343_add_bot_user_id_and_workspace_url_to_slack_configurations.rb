class AddBotUserIdAndWorkspaceUrlToSlackConfigurations < ActiveRecord::Migration[8.0]
  def change
    add_column :slack_configurations, :bot_user_id, :string
    add_column :slack_configurations, :workspace_url, :string
  end
end
