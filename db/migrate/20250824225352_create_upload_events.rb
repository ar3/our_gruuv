class CreateUploadEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :upload_events do |t|
      t.text :file_content
      t.jsonb :preview_actions, default: {}
      t.references :creator, null: false, foreign_key: { to_table: :people }
      t.references :initiator, null: false, foreign_key: { to_table: :people }
      t.datetime :attempted_at
      t.string :status, null: false, default: 'preview'
      t.jsonb :results, default: {}

      t.timestamps
    end

    add_index :upload_events, :status
    add_index :upload_events, :created_at
  end
end
