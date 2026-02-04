class RemoveTypeFromOrganizations < ActiveRecord::Migration[8.0]
  def up
    # Only remove the STI type column. Do not delete Team/Department organization rows:
    # teammates.organization_id still references organizations, so deleting would violate FK.
    # Legacy Team/Department org cleanup (if any) can be done in a later migration
    # after reassigning or removing dependent teammates.
    remove_column :organizations, :type
  end

  def down
    add_column :organizations, :type, :string

    execute <<-SQL
      UPDATE organizations SET type = 'Company' WHERE type IS NULL;
    SQL
  end
end
