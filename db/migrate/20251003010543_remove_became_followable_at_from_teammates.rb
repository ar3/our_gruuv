class RemoveBecameFollowableAtFromTeammates < ActiveRecord::Migration[8.0]
  def up
    if table_exists?(:person_organization_accesses) && !table_exists?(:teammates)
      rename_table :person_organization_accesses, :teammates
    end
    remove_index :teammates, :became_followable_at
    remove_column :teammates, :became_followable_at
  end

  def down
    add_column :teammates, :became_followable_at, :datetime
    add_index :teammates, :became_followable_at
  end
end
