class CreateSlackConfigurations < ActiveRecord::Migration[8.0]
  def change
    create_table :slack_configurations do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :workspace_id, null: false
      t.string :workspace_name, null: false
      t.string :bot_token, null: false
      t.string :default_channel, default: '#bot-test'
      t.string :bot_username, default: 'OG'
      t.string :bot_emoji, default: ':sparkles:'
      t.datetime :installed_at, null: false

      t.timestamps
    end
    
    add_index :slack_configurations, :workspace_id, unique: true
    add_index :slack_configurations, :bot_token, unique: true
  end
end
