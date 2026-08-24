# frozen_string_literal: true

class RemoveEmployeeAcknowledgementFromCheckIns < ActiveRecord::Migration[8.0]
  TABLES = %i[assignment_check_ins aspiration_check_ins position_check_ins].freeze

  def change
    TABLES.each do |table|
      remove_column table, :employee_acknowledgement, :string
    end
  end
end
