# frozen_string_literal: true

class AddJobDescriptionHrCascade < ActiveRecord::Migration[8.0]
  DISCLAIMER = "This job description is not designed to cover or contain a comprehensive list of duties or responsibilities. Duties may change or new ones may be assigned at any time."
  WORK_ENVIRONMENT = "Prolonged periods of sitting at a desk and working on a computer."
  PHYSICAL_REQUIREMENTS = "While performing the duties of this job, the employee may be regularly required to stand, sit, talk, hear, and use hands and fingers to operate a computer and keyboard. Specific vision abilities required by this job include close vision requirements due to computer work."
  TRAVEL = "Travel is on a voluntary basis."

  def up
    add_column :organizations, :job_description_disclaimer, :text
    add_column :organizations, :work_environment, :text
    add_column :organizations, :physical_requirements, :text
    add_column :organizations, :travel, :text

    execute <<~SQL.squish
      UPDATE organizations
      SET
        job_description_disclaimer = #{quote(DISCLAIMER)},
        work_environment = #{quote(WORK_ENVIRONMENT)},
        physical_requirements = #{quote(PHYSICAL_REQUIREMENTS)},
        travel = #{quote(TRAVEL)}
      WHERE job_description_disclaimer IS NULL
         OR work_environment IS NULL
         OR physical_requirements IS NULL
         OR travel IS NULL
    SQL

    change_column_null :organizations, :job_description_disclaimer, false
    change_column_null :organizations, :work_environment, false
    change_column_null :organizations, :physical_requirements, false
    change_column_null :organizations, :travel, false

    change_column_default :organizations, :job_description_disclaimer, DISCLAIMER
    change_column_default :organizations, :work_environment, WORK_ENVIRONMENT
    change_column_default :organizations, :physical_requirements, PHYSICAL_REQUIREMENTS
    change_column_default :organizations, :travel, TRAVEL

    add_column :titles, :job_description_disclaimer, :text
    add_column :titles, :work_environment, :text
    add_column :titles, :physical_requirements, :text
    add_column :titles, :travel, :text

    change_column_default :seats, :seat_disclaimer, from: DISCLAIMER, to: nil
    change_column_default :seats, :work_environment, from: WORK_ENVIRONMENT, to: nil
    change_column_default :seats, :physical_requirements, from: PHYSICAL_REQUIREMENTS, to: nil
    change_column_default :seats, :travel, from: TRAVEL, to: nil

    execute <<~SQL.squish
      UPDATE seats
      SET
        seat_disclaimer = NULL,
        work_environment = NULL,
        physical_requirements = NULL,
        travel = NULL
    SQL
  end

  def down
    change_column_default :seats, :seat_disclaimer, from: nil, to: DISCLAIMER
    change_column_default :seats, :work_environment, from: nil, to: WORK_ENVIRONMENT
    change_column_default :seats, :physical_requirements, from: nil, to: PHYSICAL_REQUIREMENTS
    change_column_default :seats, :travel, from: nil, to: TRAVEL

    execute <<~SQL.squish
      UPDATE seats
      SET
        seat_disclaimer = #{quote(DISCLAIMER)},
        work_environment = #{quote(WORK_ENVIRONMENT)},
        physical_requirements = #{quote(PHYSICAL_REQUIREMENTS)},
        travel = #{quote(TRAVEL)}
      WHERE seat_disclaimer IS NULL
         OR work_environment IS NULL
         OR physical_requirements IS NULL
         OR travel IS NULL
    SQL

    remove_column :titles, :job_description_disclaimer
    remove_column :titles, :work_environment
    remove_column :titles, :physical_requirements
    remove_column :titles, :travel

    remove_column :organizations, :job_description_disclaimer
    remove_column :organizations, :work_environment
    remove_column :organizations, :physical_requirements
    remove_column :organizations, :travel
  end
end
