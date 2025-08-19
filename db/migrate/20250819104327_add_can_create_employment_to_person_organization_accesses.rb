class AddCanCreateEmploymentToPersonOrganizationAccesses < ActiveRecord::Migration[8.0]
  def change
    add_column :person_organization_accesses, :can_create_employment, :boolean
  end
end
