class CreateAssignmentChanges < ActiveRecord::Migration[8.0]
  def change
    create_table :assignment_changes do |t|
      t.references :person, null: false, foreign_key: true
      t.references :assignment, null: true, foreign_key: true
      t.jsonb :request_data, null: false
      t.text :reason
      t.references :created_by, null: false, foreign_key: { to_table: :people }
      t.string :status, default: 'pending'

      t.timestamps
    end

    add_index :assignment_changes, :status
    add_index :assignment_changes, :request_data, using: :gin
  end
end
