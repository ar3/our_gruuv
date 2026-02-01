class SoftDeleteLegacyDepartmentOrganizations < ActiveRecord::Migration[8.0]
  def up
    # Soft delete all Department type organizations now that they've been migrated
    # to the new departments table
    execute <<-SQL
      UPDATE organizations
      SET deleted_at = NOW()
      WHERE type = 'Department'
        AND deleted_at IS NULL
    SQL
  end

  def down
    # Restore soft-deleted Department organizations
    # Note: This only restores those that were deleted by this migration
    # We can't easily distinguish them from manually archived ones
    execute <<-SQL
      UPDATE organizations
      SET deleted_at = NULL
      WHERE type = 'Department'
        AND deleted_at IS NOT NULL
    SQL
  end
end
