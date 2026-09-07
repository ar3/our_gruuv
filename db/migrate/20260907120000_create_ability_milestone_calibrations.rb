# frozen_string_literal: true

class CreateAbilityMilestoneCalibrations < ActiveRecord::Migration[8.0]
  def change
    create_table :ability_milestone_calibrations do |t|
      t.references :teammate, null: false, foreign_key: { to_table: :teammates }, index: { unique: true }
      t.datetime :employee_completed_at
      t.datetime :manager_completed_at
      t.references :manager_completed_by_teammate, null: true, foreign_key: { to_table: :teammates },
                   index: { name: "index_ability_ms_calibrations_on_manager_completed_by" }

      t.timestamps
    end

    create_table :ability_milestone_calibration_items do |t|
      t.references :ability_milestone_calibration, null: false, foreign_key: true,
                   index: { name: "index_ability_ms_calibration_items_on_calibration_id" }
      t.references :ability, null: false, foreign_key: true
      t.integer :employee_rating
      t.integer :manager_rating
      t.integer :official_milestone_level
      t.datetime :awarded_at
      t.references :awarded_by_teammate, null: true, foreign_key: { to_table: :teammates },
                   index: { name: "index_ability_ms_calibration_items_on_awarded_by" }

      t.timestamps
    end

    add_index :ability_milestone_calibration_items,
              %i[ability_milestone_calibration_id ability_id],
              unique: true,
              name: "index_ability_ms_calibration_items_on_calibration_and_ability"

    add_check_constraint :ability_milestone_calibration_items,
                         "employee_rating IS NULL OR (employee_rating >= 0 AND employee_rating <= 5)",
                         name: "ability_ms_calibration_items_employee_rating_range"
    add_check_constraint :ability_milestone_calibration_items,
                         "manager_rating IS NULL OR (manager_rating >= 0 AND manager_rating <= 5)",
                         name: "ability_ms_calibration_items_manager_rating_range"
    add_check_constraint :ability_milestone_calibration_items,
                         "official_milestone_level IS NULL OR (official_milestone_level >= 0 AND official_milestone_level <= 5)",
                         name: "ability_ms_calibration_items_official_rating_range"
  end
end
