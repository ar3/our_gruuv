class AddAssignmentsAuditSnapshotToPositions < ActiveRecord::Migration[8.0]
  def change
    add_column :positions, :assignments_audit_snapshot, :text
  end
end
