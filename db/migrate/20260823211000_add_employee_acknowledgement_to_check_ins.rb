# frozen_string_literal: true

class AddEmployeeAcknowledgementToCheckIns < ActiveRecord::Migration[8.0]
  TABLES = %i[
    position_check_ins
    assignment_check_ins
    aspiration_check_ins
  ].freeze

  def change
    TABLES.each do |table|
      add_column table, :employee_acknowledged_at, :datetime
      add_column table, :employee_acknowledgement, :string
      add_column table, :employee_acknowledgement_notes, :text
      add_index table, :employee_acknowledged_at
    end
  end
end
