# frozen_string_literal: true

class AddEmployeeAcknowledgementRequestInfoToCheckIns < ActiveRecord::Migration[8.0]
  TABLES = %i[
    position_check_ins
    assignment_check_ins
    aspiration_check_ins
  ].freeze

  def change
    TABLES.each do |table|
      add_column table, :employee_acknowledgement_request_info, :jsonb, default: {}, null: false
    end
  end
end
