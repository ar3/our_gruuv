# frozen_string_literal: true

class RemoveDeprecatedObservableMoments < ActiveRecord::Migration[8.0]
  def up
    # Remove only position/assignment/aspiration check-in moments (ability_milestone is kept)
    ids = connection.select_values(<<~SQL)
      SELECT id FROM observable_moments
      WHERE moment_type = 'check_in_completed'
        AND momentable_type IN ('PositionCheckIn', 'AssignmentCheckIn', 'AspirationCheckIn')
    SQL

    return if ids.empty?

    id_list = ids.join(',')
    # Avoid referential integrity issues: nullify FKs before deleting
    execute("UPDATE observations SET observable_moment_id = NULL WHERE observable_moment_id IN (#{id_list})")
    execute("UPDATE kudos_transactions SET observable_moment_id = NULL WHERE observable_moment_id IN (#{id_list})")
    execute("DELETE FROM observable_moments WHERE id IN (#{id_list})")
  end

  def down
    # Data cannot be restored; no-op
  end
end
