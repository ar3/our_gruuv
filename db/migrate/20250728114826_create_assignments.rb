class CreateAssignments < ActiveRecord::Migration[8.0]
  def change
    create_table :assignments do |t|
      t.string :title
      t.text :tagline
      t.text :required_activities
      t.text :handbook
      t.references :company, null: false, foreign_key: { to_table: :organizations }

      t.timestamps
    end
  end
end
