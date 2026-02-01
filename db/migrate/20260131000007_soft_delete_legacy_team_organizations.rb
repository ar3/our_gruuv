class SoftDeleteLegacyTeamOrganizations < ActiveRecord::Migration[8.0]
  def up
    # Soft-delete legacy Team records in the organizations table.
    # These have been migrated to the new teams table by migration 20260131000003.
    # We soft-delete rather than hard-delete to preserve referential integrity
    # and allow for rollback if needed.
    execute <<-SQL
      UPDATE organizations
      SET deleted_at = NOW()
      WHERE type = 'Team'
        AND deleted_at IS NULL
    SQL
  end

  def down
    # Restore soft-deleted Team organizations
    # Note: This only restores Team organizations that were soft-deleted by this migration.
    # It won't restore organizations that were already soft-deleted before.
    execute <<-SQL
      UPDATE organizations
      SET deleted_at = NULL
      WHERE type = 'Team'
        AND deleted_at IS NOT NULL
    SQL
  end
end
