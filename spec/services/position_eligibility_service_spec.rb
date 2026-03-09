require 'rails_helper'

# Report check details use qualifying_meeting/qualifying_exceeding for pass/fail.
# The eligibility show page uses CheckInRequirementsEligibility::Calculator (3-level: Exceeding, Meeting, Miss, etc.).
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
        "minimum_months_at_or_above_rating_criteria" => 1,
        "minimum_percentage_of_assignments_meeting" => 100,
        "minimum_percentage_of_assignments_exceeding" => 0
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

    it 'counts only active assignments not required by the position and reports meeting/exceeding counts' do
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
      expect(unique_check[:details][:qualifying_meeting]).to eq(1)
      expect(unique_check[:details][:qualifying_exceeding]).to be_present
    end

    it 'fails when no unique-to-you assignments are active and minimum meeting expectation is above 0%' do
      create(:assignment_tenure, teammate: teammate, assignment: required_assignment, ended_at: nil)

      report = described_class.new.check_eligibility(teammate, position)
      unique_check = report[:checks].find { |check| check[:key] == :unique_to_you_assignment_check_in_requirements }

      expect(unique_check[:status]).to eq(:failed)
      expect(unique_check[:details][:total_assignments]).to eq(0)
    end

    it 'returns not_applicable when no unique-to-you assignments and minimum meeting expectation is 0% or empty' do
      create(:assignment_tenure, teammate: teammate, assignment: required_assignment, ended_at: nil)
      position.update!(
        eligibility_requirements_explicit: {
          "unique_to_you_assignment_check_in_requirements" => {
            "minimum_months_at_or_above_rating_criteria" => 12,
            "minimum_percentage_of_assignments_meeting" => 0,
            "minimum_percentage_of_assignments_exceeding" => 0
          }
        }
      )

      report = described_class.new.check_eligibility(teammate, position)
      unique_check = report[:checks].find { |check| check[:key] == :unique_to_you_assignment_check_in_requirements }

      expect(unique_check[:status]).to eq(:not_applicable)
      expect(unique_check[:details][:total_assignments]).to eq(0)
      # With default requirements, other checks (e.g. position check-in, aspirations) may run and affect overall_eligible
      expect(report[:checks].any? { |c| c[:key] == :unique_to_you_assignment_check_in_requirements }).to be true
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

  describe 'mileage requirements' do
    let(:organization) { create(:organization, :company) }
    let(:title) { create(:title, company: organization) }
    let(:position_level) { create(:position_level, position_major_level: title.position_major_level) }
    let(:position) { create(:position, title: title, position_level: position_level) }
    let(:teammate) { create(:company_teammate, organization: organization) }
    let(:ability) { create(:ability, company: organization) }

    it 'passes when teammate meets absolute minimum mileage' do
      create(:position_ability, position: position, ability: ability, milestone_level: 2)
      create(:teammate_milestone, company_teammate: teammate, ability: ability, milestone_level: 2)
      position.update!(
        eligibility_requirements_explicit: {
          'mileage_requirements' => { 'threshold_type' => 'absolute', 'threshold_value' => 2 }
        }
      )

      report = described_class.new.check_eligibility(teammate, position)
      mileage_check = report[:checks].find { |c| c[:key] == :mileage_requirements }

      expect(mileage_check[:status]).to eq(:passed)
      expect(mileage_check[:details][:minimum_mileage_points]).to eq(2)
      expect(mileage_check[:details][:total_mileage_points]).to eq(2)
    end

    it 'fails when teammate is below absolute minimum mileage' do
      create(:position_ability, position: position, ability: ability, milestone_level: 2)
      create(:teammate_milestone, company_teammate: teammate, ability: ability, milestone_level: 1)
      position.update!(
        eligibility_requirements_explicit: {
          'mileage_requirements' => { 'threshold_type' => 'absolute', 'threshold_value' => 5 }
        }
      )

      report = described_class.new.check_eligibility(teammate, position)
      mileage_check = report[:checks].find { |c| c[:key] == :mileage_requirements }

      expect(mileage_check[:status]).to eq(:failed)
      expect(mileage_check[:details][:minimum_mileage_points]).to eq(5)
      expect(mileage_check[:details][:total_mileage_points]).to eq(1)
    end

    it 'uses percentage more than required: base 20, 20% more = 24; teammate 20 fails, 26 passes' do
      # Base = one ability at M5 => points_through(5) = 1+2+3+6+8 = 20.
      create(:position_ability, position: position, ability: ability, milestone_level: 5)
      position.update!(
        eligibility_requirements_explicit: {
          'mileage_requirements' => { 'threshold_type' => 'percentage', 'threshold_value' => 20 }
        }
      )

      # 20 * (100+20)/100 = 24 required. Teammate with 20 (M1–M5 for ability = 1+2+3+6+8) fails.
      (1..5).each { |level| create(:teammate_milestone, company_teammate: teammate, ability: ability, milestone_level: level) }
      report = described_class.new.check_eligibility(teammate, position)
      mileage_check = report[:checks].find { |c| c[:key] == :mileage_requirements }
      expect(mileage_check[:status]).to eq(:failed)
      expect(mileage_check[:details][:minimum_mileage_points]).to eq(24)
      expect(mileage_check[:details][:minimum_required_from_milestones]).to eq(20)
      expect(mileage_check[:details][:threshold_value]).to eq(20)

      # Teammate with 26 (20 + M1–M3 for a2 = 6 pts) passes
      a2 = create(:ability, company: organization)
      (1..3).each { |level| create(:teammate_milestone, company_teammate: teammate, ability: a2, milestone_level: level) }
      teammate.reload
      report2 = described_class.new.check_eligibility(teammate, position)
      mileage_check2 = report2[:checks].find { |c| c[:key] == :mileage_requirements }
      expect(mileage_check2[:details][:total_mileage_points]).to eq(26)
      expect(mileage_check2[:status]).to eq(:passed)
    end
  end

  describe '.eligibility_data_with_defaults and default requirements' do
    it 'fills in default sections when raw is empty' do
      result = described_class.eligibility_data_with_defaults({})
      expect(result['company_aspirational_values_check_in_requirements']).to eq(
        'minimum_months_at_or_above_rating_criteria' => 3,
        'minimum_percentage_of_aspirational_values_meeting' => 80,
        'minimum_percentage_of_aspirational_values_exceeding' => 0
      )
      expect(result['position_check_in_requirements']).to eq(
        'minimum_rating' => 2,
        'minimum_months_at_or_above_rating_criteria' => 3
      )
      expect(result['mileage_requirements']).to eq(
        'threshold_type' => 'percentage',
        'threshold_value' => 20
      )
    end

    it 'keeps explicit sections when present and only fills blank sections' do
      raw = {
        'position_check_in_requirements' => { 'minimum_rating' => 3, 'minimum_months_at_or_above_rating_criteria' => 6 }
      }
      result = described_class.eligibility_data_with_defaults(raw)
      expect(result['position_check_in_requirements']).to eq('minimum_rating' => 3, 'minimum_months_at_or_above_rating_criteria' => 6)
      expect(result['mileage_requirements']).to eq('threshold_type' => 'percentage', 'threshold_value' => 20)
    end

    it 'applies default position check-in and mileage when position has no eligibility data' do
      organization = create(:organization, :company)
      title = create(:title, company: organization)
      position_level = create(:position_level, position_major_level: title.position_major_level)
      position = create(:position, title: title, position_level: position_level)
      teammate = create(:company_teammate, organization: organization)
      position.update!(eligibility_requirements_explicit: {})

      report = described_class.new.check_eligibility(teammate, position)
      pos_check = report[:checks].find { |c| c[:key] == :position_check_in_requirements }
      mileage_check = report[:checks].find { |c| c[:key] == :mileage_requirements }

      expect(pos_check[:status]).not_to eq(:not_configured)
      expect(pos_check[:details][:minimum_rating]).to eq(2)
      expect(pos_check[:details][:minimum_months_at_or_above_rating_criteria]).to eq(3)
      expect(mileage_check[:details][:threshold_type]).to eq('percentage')
      expect(mileage_check[:details][:threshold_value]).to eq(20)
    end
  end
end
