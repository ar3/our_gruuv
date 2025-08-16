class CreatePersonOrganizationAccesses < ActiveRecord::Migration[8.0]
  def change
    create_table :person_organization_accesses do |t|
      t.references :person, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true
      t.boolean :can_manage_employment
      t.boolean :can_manage_maap

      t.timestamps
    end
    
    # Add indexes for performance
    add_index :person_organization_accesses, [:person_id, :organization_id], unique: true, name: 'index_person_org_access_on_person_and_org'
    add_index :person_organization_accesses, :can_manage_employment
    add_index :person_organization_accesses, :can_manage_maap
  end
end
