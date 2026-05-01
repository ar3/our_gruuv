# PaperTrail persists per-attribute diffs in +object_changes+. Without this column,
# Version#changeset is always nil and the change-history UI cannot list changed fields.
class AddObjectChangesToVersions < ActiveRecord::Migration[8.0]
  TEXT_BYTES = 1_073_741_823

  def change
    add_column :versions, :object_changes, :text, limit: TEXT_BYTES
  end
end
