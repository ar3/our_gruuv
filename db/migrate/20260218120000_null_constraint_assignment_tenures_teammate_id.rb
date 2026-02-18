# frozen_string_literal: true

class NullConstraintAssignmentTenuresTeammateId < ActiveRecord::Migration[7.0]
  def up
    nil_count = connection.select_value("SELECT COUNT(*) FROM assignment_tenures WHERE teammate_id IS NULL")
    if nil_count.to_i.positive?
      raise <<~MSG.squish
        Cannot add NOT NULL: assignment_tenures has rows with nil teammate_id.
        Fix or remove those records, then re-run the migration.
      MSG
    end
    change_column_null :assignment_tenures, :teammate_id, false
  end

  def down
    change_column_null :assignment_tenures, :teammate_id, true
  end
end
