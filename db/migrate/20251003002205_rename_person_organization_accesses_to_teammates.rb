class RenamePersonOrganizationAccessesToTeammates < ActiveRecord::Migration[8.0]
  def change
    rename_table :person_organization_accesses, :teammates
  end
end
