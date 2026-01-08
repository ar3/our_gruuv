class CreateCompanyLabelPreferences < ActiveRecord::Migration[8.0]
  def change
    create_table :company_label_preferences do |t|
      t.references :company, null: false, foreign_key: { to_table: :organizations }
      t.string :label_key, null: false
      t.string :label_value

      t.timestamps
    end

    add_index :company_label_preferences, [:company_id, :label_key], unique: true
  end
end
