# frozen_string_literal: true

class NormalizeCheckInAcknowledgementDisagreeToAgree < ActiveRecord::Migration[8.0]
  TABLES = %w[assignment_check_ins aspiration_check_ins position_check_ins].freeze

  def up
    TABLES.each do |table|
      execute <<~SQL.squish
        UPDATE #{table}
        SET employee_acknowledgement = 'agree'
        WHERE employee_acknowledgement = 'disagree'
      SQL
    end
  end

  def down
    # Irreversible: prior disagree rows cannot be distinguished from agree.
  end
end
