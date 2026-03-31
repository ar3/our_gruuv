# frozen_string_literal: true

class CreatePositionEligibilityRequirements < ActiveRecord::Migration[8.0]
  def up
    create_table :position_eligibility_requirements do |t|
      t.string :requirements_fingerprint, null: false
      t.string :mileage_threshold_type
      t.integer :mileage_threshold_value
      t.integer :position_check_in_minimum_rating
      t.integer :position_check_in_minimum_months
      t.integer :required_assignment_minimum_months
      t.decimal :required_assignment_pct_meeting, precision: 8, scale: 2
      t.decimal :required_assignment_pct_exceeding, precision: 8, scale: 2
      t.integer :unique_to_you_minimum_months
      t.decimal :unique_to_you_pct_meeting, precision: 8, scale: 2
      t.decimal :unique_to_you_pct_exceeding, precision: 8, scale: 2
      t.integer :aspirational_minimum_months
      t.decimal :aspirational_pct_meeting, precision: 8, scale: 2
      t.decimal :aspirational_pct_exceeding, precision: 8, scale: 2
      t.timestamps
    end
    add_index :position_eligibility_requirements, :requirements_fingerprint, unique: true,
              name: 'idx_position_eligibility_req_fingerprint'

    add_reference :positions, :position_eligibility_requirement, foreign_key: { to_table: :position_eligibility_requirements }, null: true

    if index_exists?(:positions, :eligibility_requirements_explicit)
      remove_index :positions, name: 'index_positions_on_eligibility_requirements_explicit'
    end
    remove_column :positions, :eligibility_requirements_explicit, :jsonb if column_exists?(:positions, :eligibility_requirements_explicit)
    remove_column :positions, :eligibility_requirements_summary, :text if column_exists?(:positions, :eligibility_requirements_summary)

    add_reference :organizations, :minor_1_position_eligibility_requirement, foreign_key: { to_table: :position_eligibility_requirements }, null: true
    add_reference :organizations, :minor_2_position_eligibility_requirement, foreign_key: { to_table: :position_eligibility_requirements }, null: true
    add_reference :organizations, :minor_3_position_eligibility_requirement, foreign_key: { to_table: :position_eligibility_requirements }, null: true

    add_reference :departments, :minor_1_position_eligibility_requirement, foreign_key: { to_table: :position_eligibility_requirements }, null: true
    add_reference :departments, :minor_2_position_eligibility_requirement, foreign_key: { to_table: :position_eligibility_requirements }, null: true
    add_reference :departments, :minor_3_position_eligibility_requirement, foreign_key: { to_table: :position_eligibility_requirements }, null: true

    say_with_time 'Seeding organization position eligibility defaults' do
      Organization.unscoped.find_each do |org|
        Organizations::PositionEligibilityDefaultSeeder.ensure!(org)
      end
    end
  end

  def down
    if defined?(Organizations::PositionEligibilityDefaultSeeder)
      Organization.unscoped.find_each do |org|
        Organizations::PositionEligibilityDefaultSeeder.revert_org_links!(org)
      end
    end

    remove_reference :departments, :minor_3_position_eligibility_requirement, foreign_key: { to_table: :position_eligibility_requirements }
    remove_reference :departments, :minor_2_position_eligibility_requirement, foreign_key: { to_table: :position_eligibility_requirements }
    remove_reference :departments, :minor_1_position_eligibility_requirement, foreign_key: { to_table: :position_eligibility_requirements }

    remove_reference :organizations, :minor_3_position_eligibility_requirement, foreign_key: { to_table: :position_eligibility_requirements }
    remove_reference :organizations, :minor_2_position_eligibility_requirement, foreign_key: { to_table: :position_eligibility_requirements }
    remove_reference :organizations, :minor_1_position_eligibility_requirement, foreign_key: { to_table: :position_eligibility_requirements }

    remove_reference :positions, :position_eligibility_requirement, foreign_key: { to_table: :position_eligibility_requirements }

    drop_table :position_eligibility_requirements

    add_column :positions, :eligibility_requirements_explicit, :jsonb, default: {}, null: false
    add_index :positions, :eligibility_requirements_explicit, using: :gin, name: 'index_positions_on_eligibility_requirements_explicit'
    add_column :positions, :eligibility_requirements_summary, :text
  end
end
