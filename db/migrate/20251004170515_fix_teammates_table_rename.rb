class FixTeammatesTableRename < ActiveRecord::Migration[8.0]
  def up
    # Check if person_organization_accesses table exists but teammates doesn't
    if table_exists?(:person_organization_accesses) && !table_exists?(:teammates)
      rename_table :person_organization_accesses, :teammates
    end
  end

  def down
    # Reverse the rename if needed
    if table_exists?(:teammates) && !table_exists?(:person_organization_accesses)
      rename_table :teammates, :person_organization_accesses
    end
  end
end
