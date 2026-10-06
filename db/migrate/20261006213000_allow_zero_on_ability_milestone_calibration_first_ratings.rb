# frozen_string_literal: true

class AllowZeroOnAbilityMilestoneCalibrationFirstRatings < ActiveRecord::Migration[8.0]
  def up
    remove_check_constraint :ability_milestone_calibration_items,
                            name: "ability_ms_calibration_items_employee_first_rating_range"
    remove_check_constraint :ability_milestone_calibration_items,
                            name: "ability_ms_calibration_items_manager_first_rating_range"

    add_check_constraint :ability_milestone_calibration_items,
                         "employee_first_rating IS NULL OR (employee_first_rating >= 0 AND employee_first_rating <= 5)",
                         name: "ability_ms_calibration_items_employee_first_rating_range"
    add_check_constraint :ability_milestone_calibration_items,
                         "manager_first_rating IS NULL OR (manager_first_rating >= 0 AND manager_first_rating <= 5)",
                         name: "ability_ms_calibration_items_manager_first_rating_range"
  end

  def down
    remove_check_constraint :ability_milestone_calibration_items,
                            name: "ability_ms_calibration_items_employee_first_rating_range"
    remove_check_constraint :ability_milestone_calibration_items,
                            name: "ability_ms_calibration_items_manager_first_rating_range"

    add_check_constraint :ability_milestone_calibration_items,
                         "employee_first_rating IS NULL OR (employee_first_rating >= 1 AND employee_first_rating <= 5)",
                         name: "ability_ms_calibration_items_employee_first_rating_range"
    add_check_constraint :ability_milestone_calibration_items,
                         "manager_first_rating IS NULL OR (manager_first_rating >= 1 AND manager_first_rating <= 5)",
                         name: "ability_ms_calibration_items_manager_first_rating_range"
  end
end
