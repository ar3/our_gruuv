require 'rails_helper'

RSpec.describe PositionTypeMaturityService, type: :service do
  let(:company) { create(:organization, :company) }
  let(:position_major_level) { create(:position_major_level) }
  let(:position_level) { create(:position_level, position_major_level: position_major_level) }
  let(:position_type) { create(:position_type, organization: company, position_major_level: position_major_level) }
  let(:service) { described_class.new(position_type) }

  describe '.calculate_phase' do
    it 'returns 1 when no positions have assignments' do
      create(:position, position_type: position_type, position_level: position_level)
      expect(described_class.calculate_phase(position_type)).to eq(1)
    end

    context 'Phase 1' do
      it 'returns 2 when at least one position has a required assignment but not all positions have required assignments' do
        position1 = create(:position, position_type: position_type, position_level: position_level)
        position2 = create(:position, position_type: position_type, position_level: create(:position_level, position_major_level: position_major_level))
        assignment = create(:assignment, company: company)
        create(:position_assignment, position: position1, assignment: assignment, assignment_type: 'required')
        # position2 has no assignments
        
        expect(described_class.calculate_phase(position_type)).to eq(2)
      end
    end

    context 'Phase 2' do
      it 'returns 3 when all positions have required assignments' do
        position1 = create(:position, position_type: position_type, position_level: position_level)
        position2 = create(:position, position_type: position_type, position_level: create(:position_level, position_major_level: position_major_level))
        
        assignment1 = create(:assignment, company: company)
        assignment2 = create(:assignment, company: company)
        
        create(:position_assignment, position: position1, assignment: assignment1, assignment_type: 'required')
        create(:position_assignment, position: position2, assignment: assignment2, assignment_type: 'required')
        
        expect(described_class.calculate_phase(position_type)).to eq(3)
      end

      it 'returns 2 when not all positions have required assignments' do
        position1 = create(:position, position_type: position_type, position_level: position_level)
        position2 = create(:position, position_type: position_type, position_level: create(:position_level, position_major_level: position_major_level))
        
        assignment = create(:assignment, company: company)
        create(:position_assignment, position: position1, assignment: assignment, assignment_type: 'required')
        # position2 has no assignments
        
        expect(described_class.calculate_phase(position_type)).to eq(2)
      end
    end

    context 'Phase 3' do
      it 'returns 4 when employees have check-ins on required assignments' do
        # Set up phases 1 and 2: all positions have required assignments
        position1 = create(:position, position_type: position_type, position_level: position_level)
        position2 = create(:position, position_type: position_type, position_level: create(:position_level, position_major_level: position_major_level))
        assignment1 = create(:assignment, company: company)
        assignment2 = create(:assignment, company: company)
        create(:position_assignment, position: position1, assignment: assignment1, assignment_type: 'required')
        create(:position_assignment, position: position2, assignment: assignment2, assignment_type: 'required')
        
        # Set up phase 3: employment tenure and check-in
        person = create(:person)
        teammate = create(:teammate, person: person, organization: company)
        # Create employment tenure directly to avoid factory's after(:build) hook that creates a new position
        employment_tenure = EmploymentTenure.create!(
          teammate: teammate,
          position: position1,
          company: company,
          started_at: 1.month.ago
        )
        create(:assignment_check_in, teammate: teammate, assignment: assignment1)
        
        expect(described_class.calculate_phase(position_type)).to eq(4)
      end

      it 'returns 3 when positions have tenures but no check-ins' do
        # Set up phases 1 and 2: all positions have required assignments
        position1 = create(:position, position_type: position_type, position_level: position_level)
        position2 = create(:position, position_type: position_type, position_level: create(:position_level, position_major_level: position_major_level))
        assignment1 = create(:assignment, company: company)
        assignment2 = create(:assignment, company: company)
        create(:position_assignment, position: position1, assignment: assignment1, assignment_type: 'required')
        create(:position_assignment, position: position2, assignment: assignment2, assignment_type: 'required')
        
        # Set up employment tenure but no check-ins
        person = create(:person)
        teammate = create(:teammate, person: person, organization: company)
        EmploymentTenure.create!(teammate: teammate, position: position1, company: company, started_at: 1.month.ago)
        # No check-ins
        
        expect(described_class.calculate_phase(position_type)).to eq(3)
      end
    end

    context 'Phase 4' do
      it 'returns 5 when all required assignments have ability requirements' do
        # Set up phases 1-3: all positions have required assignments, tenures, and check-ins
        position1 = create(:position, position_type: position_type, position_level: position_level)
        position2 = create(:position, position_type: position_type, position_level: create(:position_level, position_major_level: position_major_level))
        assignment1 = create(:assignment, company: company)
        assignment2 = create(:assignment, company: company)
        create(:position_assignment, position: position1, assignment: assignment1, assignment_type: 'required')
        create(:position_assignment, position: position2, assignment: assignment2, assignment_type: 'required')
        
        person = create(:person)
        teammate = create(:teammate, person: person, organization: company)
        EmploymentTenure.create!(teammate: teammate, position: position1, company: company, started_at: 1.month.ago)
        create(:assignment_check_in, teammate: teammate, assignment: assignment1)
        
        # Set up phase 4: all required assignments have ability requirements
        ability = create(:ability, organization: company)
        create(:assignment_ability, assignment: assignment1, ability: ability, milestone_level: 1)
        create(:assignment_ability, assignment: assignment2, ability: ability, milestone_level: 1)
        
        expect(described_class.calculate_phase(position_type)).to eq(5)
      end

      it 'returns 4 when assignments exist but not all have abilities' do
        # Set up phases 1-3: all positions have required assignments, tenures, and check-ins
        position1 = create(:position, position_type: position_type, position_level: position_level)
        position2 = create(:position, position_type: position_type, position_level: create(:position_level, position_major_level: position_major_level))
        assignment1 = create(:assignment, company: company)
        assignment2 = create(:assignment, company: company)
        create(:position_assignment, position: position1, assignment: assignment1, assignment_type: 'required')
        create(:position_assignment, position: position2, assignment: assignment2, assignment_type: 'required')
        
        person = create(:person)
        teammate = create(:teammate, person: person, organization: company)
        EmploymentTenure.create!(teammate: teammate, position: position1, company: company, started_at: 1.month.ago)
        create(:assignment_check_in, teammate: teammate, assignment: assignment1)
        
        # Set up phase 4 partially: only some assignments have abilities
        ability = create(:ability, organization: company)
        create(:assignment_ability, assignment: assignment1, ability: ability, milestone_level: 1)
        # assignment2 has no abilities
        
        expect(described_class.calculate_phase(position_type)).to eq(4)
      end
    end

    context 'Phase 5' do
      it 'returns 6 when all abilities have at least 2 milestones defined' do
        # Set up phases 1-4: all positions have required assignments, tenures, check-ins, and ability requirements
        position1 = create(:position, position_type: position_type, position_level: position_level)
        position2 = create(:position, position_type: position_type, position_level: create(:position_level, position_major_level: position_major_level))
        assignment1 = create(:assignment, company: company)
        assignment2 = create(:assignment, company: company)
        create(:position_assignment, position: position1, assignment: assignment1, assignment_type: 'required')
        create(:position_assignment, position: position2, assignment: assignment2, assignment_type: 'required')
        
        person = create(:person)
        teammate = create(:teammate, person: person, organization: company)
        EmploymentTenure.create!(teammate: teammate, position: position1, company: company, started_at: 1.month.ago)
        create(:assignment_check_in, teammate: teammate, assignment: assignment1)
        
        # Set up phase 4: all required assignments have ability requirements
        ability = create(:ability, 
          organization: company,
          milestone_1_description: 'Milestone 1',
          milestone_2_description: 'Milestone 2'
        )
        create(:assignment_ability, assignment: assignment1, ability: ability, milestone_level: 1)
        create(:assignment_ability, assignment: assignment2, ability: ability, milestone_level: 1)
        
        expect(described_class.calculate_phase(position_type)).to eq(6)
      end

      it 'returns 5 when abilities exist but not all have 2 milestones' do
        # Set up phases 1-4: all positions have required assignments, tenures, check-ins, and ability requirements
        position1 = create(:position, position_type: position_type, position_level: position_level)
        position2 = create(:position, position_type: position_type, position_level: create(:position_level, position_major_level: position_major_level))
        assignment1 = create(:assignment, company: company)
        assignment2 = create(:assignment, company: company)
        create(:position_assignment, position: position1, assignment: assignment1, assignment_type: 'required')
        create(:position_assignment, position: position2, assignment: assignment2, assignment_type: 'required')
        
        person = create(:person)
        teammate = create(:teammate, person: person, organization: company)
        EmploymentTenure.create!(teammate: teammate, position: position1, company: company, started_at: 1.month.ago)
        create(:assignment_check_in, teammate: teammate, assignment: assignment1)
        
        # Set up phase 4: all required assignments have ability requirements
        ability1 = create(:ability, organization: company, milestone_1_description: 'Milestone 1', milestone_2_description: 'Milestone 2')
        ability2 = create(:ability, organization: company, milestone_1_description: 'Milestone 1')  # Missing milestone_2
        create(:assignment_ability, assignment: assignment1, ability: ability1, milestone_level: 1)
        create(:assignment_ability, assignment: assignment2, ability: ability2, milestone_level: 1)
        
        expect(described_class.calculate_phase(position_type)).to eq(5)
      end
    end

    context 'Phase 6' do
      it 'returns 7 when all abilities have milestone attainments' do
        # Set up phases 1-5: positions, assignments, tenures, check-ins, abilities with milestones
        position1 = create(:position, position_type: position_type, position_level: position_level)
        position2 = create(:position, position_type: position_type, position_level: create(:position_level, position_major_level: position_major_level))
        assignment1 = create(:assignment, company: company)
        assignment2 = create(:assignment, company: company)
        create(:position_assignment, position: position1, assignment: assignment1, assignment_type: 'required')
        create(:position_assignment, position: position2, assignment: assignment2, assignment_type: 'required')
        
        person = create(:person)
        teammate = create(:teammate, person: person, organization: company)
        EmploymentTenure.create!(teammate: teammate, position: position1, company: company, started_at: 1.month.ago)
        create(:assignment_check_in, teammate: teammate, assignment: assignment1)
        
        ability = create(:ability, 
          organization: company,
          milestone_1_description: 'Milestone 1',
          milestone_2_description: 'Milestone 2'
        )
        create(:assignment_ability, assignment: assignment1, ability: ability, milestone_level: 1)
        create(:assignment_ability, assignment: assignment2, ability: ability, milestone_level: 1)
        
        # Set up phase 6: all abilities have milestone attainments
        create(:teammate_milestone, teammate: teammate, ability: ability, milestone_level: 1, certifying_teammate: create(:teammate, person: person, organization: organization))
        
        expect(described_class.calculate_phase(position_type)).to eq(7)
      end

      it 'returns 6 when abilities exist but not all have attainments' do
        # Set up phases 1-5: positions, assignments, tenures, check-ins, abilities with milestones
        position1 = create(:position, position_type: position_type, position_level: position_level)
        position2 = create(:position, position_type: position_type, position_level: create(:position_level, position_major_level: position_major_level))
        assignment1 = create(:assignment, company: company)
        assignment2 = create(:assignment, company: company)
        create(:position_assignment, position: position1, assignment: assignment1, assignment_type: 'required')
        create(:position_assignment, position: position2, assignment: assignment2, assignment_type: 'required')
        
        person = create(:person)
        teammate = create(:teammate, person: person, organization: company)
        EmploymentTenure.create!(teammate: teammate, position: position1, company: company, started_at: 1.month.ago)
        create(:assignment_check_in, teammate: teammate, assignment: assignment1)
        
        ability1 = create(:ability, organization: company, milestone_1_description: 'Milestone 1', milestone_2_description: 'Milestone 2')
        ability2 = create(:ability, organization: company, milestone_1_description: 'Milestone 1', milestone_2_description: 'Milestone 2')
        create(:assignment_ability, assignment: assignment1, ability: ability1, milestone_level: 1)
        create(:assignment_ability, assignment: assignment2, ability: ability2, milestone_level: 1)
        
        # Set up phase 6 partially: only some abilities have milestone attainments
        create(:teammate_milestone, teammate: teammate, ability: ability1, milestone_level: 1, certified_by: person)
        # ability2 has no teammate milestones
        
        expect(described_class.calculate_phase(position_type)).to eq(6)
      end
    end

    context 'Phase 7' do
      it 'returns 8 when all positions have eligibility_requirements_summary' do
        # Set up phases 1-6: positions, assignments, tenures, check-ins, abilities with milestones, teammate milestones
        # Use old updated_at timestamps so phase 8 isn't met
        position1 = create(:position, position_type: position_type, position_level: position_level, eligibility_requirements_summary: 'Requirements', updated_at: 7.months.ago)
        position2 = create(:position, position_type: position_type, position_level: create(:position_level, position_major_level: position_major_level), eligibility_requirements_summary: 'Requirements', updated_at: 7.months.ago)
        assignment1 = create(:assignment, company: company, updated_at: 7.months.ago)
        assignment2 = create(:assignment, company: company, updated_at: 7.months.ago)
        create(:position_assignment, position: position1, assignment: assignment1, assignment_type: 'required')
        create(:position_assignment, position: position2, assignment: assignment2, assignment_type: 'required')
        
        person = create(:person)
        teammate = create(:teammate, person: person, organization: company)
        EmploymentTenure.create!(teammate: teammate, position: position1, company: company, started_at: 1.month.ago)
        create(:assignment_check_in, teammate: teammate, assignment: assignment1)
        
        ability = create(:ability, 
          organization: company,
          milestone_1_description: 'Milestone 1',
          milestone_2_description: 'Milestone 2',
          updated_at: 7.months.ago
        )
        create(:assignment_ability, assignment: assignment1, ability: ability, milestone_level: 1)
        create(:assignment_ability, assignment: assignment2, ability: ability, milestone_level: 1)
        create(:teammate_milestone, teammate: teammate, ability: ability, milestone_level: 1, certifying_teammate: create(:teammate, person: person, organization: organization))
        
        expect(described_class.calculate_phase(position_type)).to eq(8)
      end

      it 'returns 7 when positions exist but not all have eligibility_requirements_summary' do
        # Set up phases 1-6: positions, assignments, tenures, check-ins, abilities with milestones, teammate milestones
        # Use old updated_at timestamps so phase 8 isn't met
        position1 = create(:position, position_type: position_type, position_level: position_level, eligibility_requirements_summary: 'Requirements', updated_at: 7.months.ago)
        position2 = create(:position, position_type: position_type, position_level: create(:position_level, position_major_level: position_major_level), updated_at: 7.months.ago)
        # position2 has nil eligibility_requirements_summary
        assignment1 = create(:assignment, company: company, updated_at: 7.months.ago)
        assignment2 = create(:assignment, company: company, updated_at: 7.months.ago)
        create(:position_assignment, position: position1, assignment: assignment1, assignment_type: 'required')
        create(:position_assignment, position: position2, assignment: assignment2, assignment_type: 'required')
        
        person = create(:person)
        teammate = create(:teammate, person: person, organization: company)
        EmploymentTenure.create!(teammate: teammate, position: position1, company: company, started_at: 1.month.ago)
        create(:assignment_check_in, teammate: teammate, assignment: assignment1)
        
        ability = create(:ability, 
          organization: company,
          milestone_1_description: 'Milestone 1',
          milestone_2_description: 'Milestone 2',
          updated_at: 7.months.ago
        )
        create(:assignment_ability, assignment: assignment1, ability: ability, milestone_level: 1)
        create(:assignment_ability, assignment: assignment2, ability: ability, milestone_level: 1)
        create(:teammate_milestone, teammate: teammate, ability: ability, milestone_level: 1, certifying_teammate: create(:teammate, person: person, organization: organization))
        
        expect(described_class.calculate_phase(position_type)).to eq(7)
      end
    end

    context 'Phase 8' do
      xit 'returns 9 when ≥5% of entities updated in last 6 months' do
        # Set up phases 1-7: positions, assignments, tenures, check-ins, abilities with milestones, teammate milestones, eligibility summaries
        position1 = create(:position, position_type: position_type, position_level: position_level, eligibility_requirements_summary: 'Requirements', updated_at: 3.months.ago)
        position2 = create(:position, position_type: position_type, position_level: create(:position_level, position_major_level: position_major_level), eligibility_requirements_summary: 'Requirements', updated_at: 3.months.ago)
        assignment1 = create(:assignment, company: company, updated_at: 2.months.ago)
        assignment2 = create(:assignment, company: company, updated_at: 2.months.ago)
        create(:position_assignment, position: position1, assignment: assignment1, assignment_type: 'required')
        create(:position_assignment, position: position2, assignment: assignment2, assignment_type: 'required')
        
        person = create(:person)
        teammate = create(:teammate, person: person, organization: company)
        EmploymentTenure.create!(teammate: teammate, position: position1, company: company, started_at: 1.month.ago)
        create(:assignment_check_in, teammate: teammate, assignment: assignment1)
        
        ability = create(:ability, 
          organization: company,
          milestone_1_description: 'Milestone 1',
          milestone_2_description: 'Milestone 2',
          updated_at: 1.month.ago
        )
        create(:assignment_ability, assignment: assignment1, ability: ability, milestone_level: 1)
        create(:assignment_ability, assignment: assignment2, ability: ability, milestone_level: 1)
        create(:teammate_milestone, teammate: teammate, ability: ability, milestone_level: 1, certifying_teammate: create(:teammate, person: person, organization: organization))
        
        # Total entities: 6 (2 positions, 2 assignments, 2 abilities)
        # Updated in last 6 months: 6 (all)
        # Percentage: 100% >= 5%
        # Note: No published observations, so phase 9 isn't met
        
        expect(described_class.calculate_phase(position_type)).to eq(9)
      end

      it 'returns 8 when <5% of entities updated in last 6 months' do
        # Set up phases 1-7: positions, assignments, tenures, check-ins, abilities with milestones, teammate milestones, eligibility summaries
        position1 = create(:position, position_type: position_type, position_level: position_level, eligibility_requirements_summary: 'Requirements', updated_at: 7.months.ago)
        position2 = create(:position, position_type: position_type, position_level: create(:position_level, position_major_level: position_major_level), eligibility_requirements_summary: 'Requirements', updated_at: 7.months.ago)
        assignment1 = create(:assignment, company: company, updated_at: 8.months.ago)
        assignment2 = create(:assignment, company: company, updated_at: 8.months.ago)
        create(:position_assignment, position: position1, assignment: assignment1, assignment_type: 'required')
        create(:position_assignment, position: position2, assignment: assignment2, assignment_type: 'required')
        
        person = create(:person)
        teammate = create(:teammate, person: person, organization: company)
        EmploymentTenure.create!(teammate: teammate, position: position1, company: company, started_at: 1.month.ago)
        create(:assignment_check_in, teammate: teammate, assignment: assignment1)
        
        ability = create(:ability, 
          organization: company,
          milestone_1_description: 'Milestone 1',
          milestone_2_description: 'Milestone 2',
          updated_at: 9.months.ago
        )
        create(:assignment_ability, assignment: assignment1, ability: ability, milestone_level: 1)
        create(:assignment_ability, assignment: assignment2, ability: ability, milestone_level: 1)
        create(:teammate_milestone, teammate: teammate, ability: ability, milestone_level: 1, certifying_teammate: create(:teammate, person: person, organization: organization))
        
        # Total entities: 6 (2 positions, 2 assignments, 2 abilities)
        # Updated in last 6 months: 0
        # Percentage: 0% < 5%
        
        expect(described_class.calculate_phase(position_type)).to eq(8)
      end
    end

    context 'Phase 9' do
      it 'returns 9 when ≥10% have published observations in last 6 months' do
        # Set up phases 1-8: positions, assignments, tenures, check-ins, abilities with milestones, teammate milestones, eligibility summaries, updated entities
        position1 = create(:position, position_type: position_type, position_level: position_level, eligibility_requirements_summary: 'Requirements', updated_at: 3.months.ago)
        position2 = create(:position, position_type: position_type, position_level: create(:position_level, position_major_level: position_major_level), eligibility_requirements_summary: 'Requirements', updated_at: 3.months.ago)
        assignment1 = create(:assignment, company: company, updated_at: 2.months.ago)
        assignment2 = create(:assignment, company: company, updated_at: 2.months.ago)
        create(:position_assignment, position: position1, assignment: assignment1, assignment_type: 'required')
        create(:position_assignment, position: position2, assignment: assignment2, assignment_type: 'required')
        
        person = create(:person)
        teammate = create(:teammate, person: person, organization: company)
        EmploymentTenure.create!(teammate: teammate, position: position1, company: company, started_at: 1.month.ago)
        create(:assignment_check_in, teammate: teammate, assignment: assignment1)
        
        ability = create(:ability, 
          organization: company,
          milestone_1_description: 'Milestone 1',
          milestone_2_description: 'Milestone 2',
          updated_at: 1.month.ago
        )
        create(:assignment_ability, assignment: assignment1, ability: ability, milestone_level: 1)
        create(:assignment_ability, assignment: assignment2, ability: ability, milestone_level: 1)
        create(:teammate_milestone, teammate: teammate, ability: ability, milestone_level: 1, certifying_teammate: create(:teammate, person: person, organization: organization))
        
        # Set up phase 9: published observations
        observer = create(:person)
        observation = create(:observation, observer: observer, company: company, published_at: 1.month.ago)
        create(:observation_rating, observation: observation, rateable: ability, rating: 'agree')
        
        # Total entities: 6 (2 positions, 2 assignments, 2 abilities)
        # With published observations: 1 (ability)
        # Percentage: 16.67% >= 10%
        
        expect(described_class.calculate_phase(position_type)).to eq(9)
      end

      it 'returns 8 when <10% have published observations' do
        # Set up phases 1-8: positions, assignments, tenures, check-ins, abilities with milestones, teammate milestones, eligibility summaries, updated entities
        position1 = create(:position, position_type: position_type, position_level: position_level, eligibility_requirements_summary: 'Requirements', updated_at: 3.months.ago)
        position2 = create(:position, position_type: position_type, position_level: create(:position_level, position_major_level: position_major_level), eligibility_requirements_summary: 'Requirements', updated_at: 3.months.ago)
        assignment1 = create(:assignment, company: company, updated_at: 2.months.ago)
        assignment2 = create(:assignment, company: company, updated_at: 2.months.ago)
        create(:position_assignment, position: position1, assignment: assignment1, assignment_type: 'required')
        create(:position_assignment, position: position2, assignment: assignment2, assignment_type: 'required')
        
        person = create(:person)
        teammate = create(:teammate, person: person, organization: company)
        EmploymentTenure.create!(teammate: teammate, position: position1, company: company, started_at: 1.month.ago)
        create(:assignment_check_in, teammate: teammate, assignment: assignment1)
        
        ability = create(:ability, 
          organization: company,
          milestone_1_description: 'Milestone 1',
          milestone_2_description: 'Milestone 2',
          updated_at: 1.month.ago
        )
        create(:assignment_ability, assignment: assignment1, ability: ability, milestone_level: 1)
        create(:assignment_ability, assignment: assignment2, ability: ability, milestone_level: 1)
        create(:teammate_milestone, teammate: teammate, ability: ability, milestone_level: 1, certifying_teammate: create(:teammate, person: person, organization: organization))
        
        # No published observations (or <10%)
        # Total entities: 6 (2 positions, 2 assignments, 2 abilities)
        # With published observations: 0
        # Percentage: 0% < 10%
        
        expect(described_class.calculate_phase(position_type)).to eq(8)
      end
    end
  end

  describe '.next_steps_message' do
    it 'returns message for phase 1' do
      create(:position, position_type: position_type, position_level: position_level)
      message = described_class.next_steps_message(position_type)
      expect(message).to include('all positions have at least one required assignment')
    end

    it 'returns congratulations message for phase 9' do
      # Set up all phases to be met (phases 1-9)
      position1 = create(:position, position_type: position_type, position_level: position_level, eligibility_requirements_summary: 'Requirements', updated_at: 3.months.ago)
      position2 = create(:position, position_type: position_type, position_level: create(:position_level, position_major_level: position_major_level), eligibility_requirements_summary: 'Requirements', updated_at: 3.months.ago)
      assignment1 = create(:assignment, company: company, updated_at: 2.months.ago)
      assignment2 = create(:assignment, company: company, updated_at: 2.months.ago)
      create(:position_assignment, position: position1, assignment: assignment1, assignment_type: 'required')
      create(:position_assignment, position: position2, assignment: assignment2, assignment_type: 'required')
      
      person = create(:person)
      teammate = create(:teammate, person: person, organization: company)
      EmploymentTenure.create!(teammate: teammate, position: position1, company: company, started_at: 1.month.ago)
      create(:assignment_check_in, teammate: teammate, assignment: assignment1)
      
      ability = create(:ability, 
        organization: company,
        milestone_1_description: 'Milestone 1',
        milestone_2_description: 'Milestone 2',
        updated_at: 1.month.ago
      )
      create(:assignment_ability, assignment: assignment1, ability: ability, milestone_level: 1)
      create(:assignment_ability, assignment: assignment2, ability: ability, milestone_level: 1)
      create(:teammate_milestone, teammate: teammate, ability: ability, milestone_level: 1, certified_by: person)
      
      # Set up phase 9: published observations
      observer = create(:person)
      observation = create(:observation, observer: observer, company: company, published_at: 1.month.ago)
      create(:observation_rating, observation: observation, rateable: ability, rating: 'agree')
      
      message = described_class.next_steps_message(position_type)
      expect(message).to include('Congratulations')
      expect(message).to include('Phase 9')
    end
  end

  describe '.phase_status' do
    it 'returns array of 9 booleans' do
      status = described_class.phase_status(position_type)
      expect(status.length).to eq(9)
      expect(status.all? { |s| [true, false].include?(s) }).to be true
    end

    it 'returns correct status for each phase' do
      # Create one position with assignment (phase 1 met, phase 2 met since all positions have assignments)
      position = create(:position, position_type: position_type, position_level: position_level)
      assignment = create(:assignment, company: company)
      create(:position_assignment, position: position, assignment: assignment, assignment_type: 'required')
      
      status = described_class.phase_status(position_type)
      expect(status[0]).to be true  # Phase 1 met - at least one position has required assignment
      expect(status[1]).to be true # Phase 2 met - all positions (just one) have required assignments
      expect(status[2]).to be false # Phase 3 not met - no employment tenures or check-ins
    end
  end
end

