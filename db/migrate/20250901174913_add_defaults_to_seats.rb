class AddDefaultsToSeats < ActiveRecord::Migration[8.0]
  def change
    change_column_default :seats, :seat_disclaimer, from: nil, to: "This job description is not designed to cover or contain a comprehensive list of duties or responsibilities. Duties may change or new ones may be assigned at any time."
    change_column_default :seats, :work_environment, from: nil, to: "Prolonged periods of sitting at a desk and working on a computer."
    change_column_default :seats, :physical_requirements, from: nil, to: "While performing the duties of this job, the employee may be regularly required to stand, sit, talk, hear, and use hands and fingers to operate a computer and keyboard. Specific vision abilities required by this job include close vision requirements due to computer work."
    change_column_default :seats, :travel, from: nil, to: "Travel is on a voluntary basis."
  end
end
