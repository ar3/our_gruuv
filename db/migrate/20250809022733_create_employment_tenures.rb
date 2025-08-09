class CreateEmploymentTenures < ActiveRecord::Migration[8.0]
  def change
    create_table :employment_tenures do |t|
      t.references :person, null: false, foreign_key: true
      t.references :company, null: false, foreign_key: { to_table: :organizations }
      t.references :position, null: false, foreign_key: true
      t.references :manager, null: true, foreign_key: { to_table: :people }
      t.datetime :started_at, null: false
      t.datetime :ended_at

      t.timestamps
    end
    
    add_index :employment_tenures, [:person_id, :company_id, :started_at], name: 'index_employment_tenures_on_person_company_started'
  end
end
