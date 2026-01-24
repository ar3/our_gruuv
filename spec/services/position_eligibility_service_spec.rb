require 'rails_helper'

RSpec.describe PositionEligibilityService do
  describe '#check_unique_to_you_assignment_check_ins' do
    let(:organization) { create(:organization, :company) }
    let(:position_type) { create(:position_type, organization: organization) }
    let(:position_level) { create(:position_level, position_major_level: position_type.position_major_level) }
    let(:position) { create(:position, position_type: position_type, position_level: position_level) }
    let(:teammate) { create(:company_teammate, organization: organization) }
    let(:required_assignment) { create(:assignment, company: organization) }
    let(:unique_assignment) { create(:assignment, company: organization) }

    let(:requirements) do
      {
        "minimum_rating" => "meeting",
        "minimum_months_at_or_above_rating_criteria" => 1,
        "minimum_percentage_of_assignments" => 100
      }
    end

    before do
      create(:position_assignment, position: position, assignment: required_assignment, assignment_type: 'required')
      position.update!(
        eligibility_requirements_explicit: {
          "unique_to_you_assignment_check_in_requirements" => requirements
        }
      )
    end

    it 'counts only active assignments not required by the position' do
      create(:assignment_tenure, teammate: teammate, assignment: required_assignment, ended_at: nil)
      create(:assignment_tenure, teammate: teammate, assignment: unique_assignment, ended_at: nil)

      create(
        :assignment_check_in,
        :officially_completed,
        teammate: teammate,
        assignment: unique_assignment,
        check_in_started_on: Date.current
      )

      report = described_class.new.check_eligibility(teammate, position)
      unique_check = report[:checks].find { |check| check[:key] == :unique_to_you_assignment_check_in_requirements }

      expect(unique_check[:status]).to eq(:passed)
      expect(unique_check[:details][:total_assignments]).to eq(1)
      expect(unique_check[:details][:qualifying_assignments]).to eq(1)
    end

    it 'fails when no unique-to-you assignments are active' do
      create(:assignment_tenure, teammate: teammate, assignment: required_assignment, ended_at: nil)

      report = described_class.new.check_eligibility(teammate, position)
      unique_check = report[:checks].find { |check| check[:key] == :unique_to_you_assignment_check_in_requirements }

      expect(unique_check[:status]).to eq(:failed)
      expect(unique_check[:details][:total_assignments]).to eq(0)
    end
  end
end
