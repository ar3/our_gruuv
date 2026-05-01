class AddOutcomesAuditSnapshotToAssignments < ActiveRecord::Migration[8.0]
  def up
    add_column :assignments, :outcomes_audit_snapshot, :text

    say_with_time "Backfilling outcomes_audit_snapshot for existing assignments" do
      Assignment.reset_column_information
      Assignment.find_each do |assignment|
        assignment.update_column(:outcomes_audit_snapshot, assignment.computed_outcomes_audit_snapshot)
      end
    end
  end

  def down
    remove_column :assignments, :outcomes_audit_snapshot
  end
end
