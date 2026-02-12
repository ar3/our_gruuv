require 'rails_helper'

RSpec.describe PositionEligibilityService do
  describe '#check_unique_to_you_assignment_check_ins' do
    let(:organization) { create(:organization, :company) }
    let(:title) { create(:title, company: organization) }
    let(:position_level) { create(:position_level, position_major_level: title.position_major_level) }
    let(:position) { create(:position, title: title, position_level: position_level) }
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

  describe 'milestone requirements (derived including position direct)' do
    let(:organization) { create(:organization, :company) }
    let(:title) { create(:title, company: organization) }
    let(:position_level) { create(:position_level, position_major_level: title.position_major_level) }
    let(:position) { create(:position, title: title, position_level: position_level) }
    let(:teammate) { create(:company_teammate, organization: organization) }
    let(:ability) { create(:ability, company: organization) }

    it 'includes position_abilities in derived milestone requirements and checks teammate' do
      create(:position_ability, position: position, ability: ability, milestone_level: 2)
      create(:teammate_milestone, company_teammate: teammate, ability: ability, milestone_level: 2)

      report = described_class.new.check_eligibility(teammate, position)
      milestone_check = report[:checks].find { |c| c[:key] == :milestone_requirements }

      expect(milestone_check[:status]).to eq(:passed)
      expect(milestone_check[:details][:requirements].size).to eq(1)
      expect(milestone_check[:details][:requirements].first[:ability_id]).to eq(ability.id)
      expect(milestone_check[:details][:requirements].first[:minimum_milestone_level]).to eq(2)
    end

    it 'fails when teammate does not meet position direct milestone level' do
      create(:position_ability, position: position, ability: ability, milestone_level: 3)
      create(:teammate_milestone, company_teammate: teammate, ability: ability, milestone_level: 1)

      report = described_class.new.check_eligibility(teammate, position)
      milestone_check = report[:checks].find { |c| c[:key] == :milestone_requirements }

      expect(milestone_check[:status]).to eq(:failed)
    end
  end
end
