class CreateOneOnOneLinks < ActiveRecord::Migration[8.0]
  def change
    create_table :one_on_one_links do |t|
      t.references :teammate, null: false, foreign_key: true, index: true
      t.string :url
      t.jsonb :deep_integration_config, default: {}

      t.timestamps
    end
  end
end
