# frozen_string_literal: true

class AddRatingAuditToAbilityMilestoneCalibrationItems < ActiveRecord::Migration[8.0]
  def change
    change_table :ability_milestone_calibration_items, bulk: true do |t|
      t.integer :employee_first_rating
      t.datetime :employee_first_rated_at
      t.datetime :employee_rating_changed_at
      t.integer :manager_first_rating
      t.datetime :manager_first_rated_at
      t.datetime :manager_rating_changed_at
    end

    add_check_constraint :ability_milestone_calibration_items,
                         "employee_first_rating IS NULL OR (employee_first_rating >= 1 AND employee_first_rating <= 5)",
                         name: "ability_ms_calibration_items_employee_first_rating_range"
    add_check_constraint :ability_milestone_calibration_items,
                         "manager_first_rating IS NULL OR (manager_first_rating >= 1 AND manager_first_rating <= 5)",
                         name: "ability_ms_calibration_items_manager_first_rating_range"
  end
end
