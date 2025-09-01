class CreateSeats < ActiveRecord::Migration[8.0]
  def change
    create_table :seats do |t|
      t.references :position_type, null: false, foreign_key: true
      t.date :seat_needed_by, null: false
      t.string :job_classification, default: "Salaried Exempt"
      t.string :reports_to
      t.string :team
      t.text :reports
      t.text :measurable_outcomes
      t.text :seat_disclaimer, default: "This job description is not designed to cover or contain a comprehensive list of duties or responsibilities. Duties may change or new ones may be assigned at any time."
      t.text :work_environment, default: "Prolonged periods of sitting at a desk and working on a computer."
      t.text :physical_requirements, default: "While performing the duties of this job, the employee may be regularly required to stand, sit, talk, hear, and use hands and fingers to operate a computer and keyboard. Specific vision abilities required by this job include close vision requirements due to computer work."
      t.text :travel, default: "Travel is on a voluntary basis."
      t.text :why_needed
      t.text :why_now
      t.text :costs_risks
      t.string :state, default: 'draft', null: false

      t.timestamps
    end

    add_index :seats, [:position_type_id, :seat_needed_by], unique: true, name: 'index_seats_on_position_type_and_needed_by'
  end
end
