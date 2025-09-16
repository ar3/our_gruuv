class CreateMaapSnapshots < ActiveRecord::Migration[8.0]
  def change
    create_table :maap_snapshots do |t|
      t.references :employee, null: true, foreign_key: { to_table: :people }
      t.references :created_by, null: true, foreign_key: { to_table: :people }
      t.references :company, null: true, foreign_key: { to_table: :organizations }
      
      t.string :change_type, null: false
      t.text :reason, null: false
      t.jsonb :maap_data, null: false, default: {}
      t.jsonb :request_info, null: false, default: {}
      t.date :effective_date, null: true
      
      t.timestamps
    end
    
    add_index :maap_snapshots, :change_type
    add_index :maap_snapshots, :effective_date
    add_index :maap_snapshots, :maap_data, using: :gin
    add_index :maap_snapshots, :request_info, using: :gin
  end
end
