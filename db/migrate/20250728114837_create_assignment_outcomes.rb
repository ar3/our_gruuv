class CreateAssignmentOutcomes < ActiveRecord::Migration[8.0]
  def change
    create_table :assignment_outcomes do |t|
      t.text :description
      t.references :assignment, null: false, foreign_key: true

      t.timestamps
    end
  end
end
