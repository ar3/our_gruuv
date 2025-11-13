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
      it 'returns 1 when at least one position has a required assignment' do
        position = create(:position, position_type: position_type, position_level: position_level)
        assignment = create(:assignment, company: company)
        create(:position_assignment, position: position, assignment: assignment, assignment_type: 'required')
        
        expect(described_class.calculate_phase(position_type)).to eq(1)
      end
    end

    context 'Phase 2' do
      it 'returns 2 when all positions have required assignments' do
        position1 = create(:position, position_type: position_type, position_level: position_level)
        position2 = create(:position, position_type: position_type, position_level: create(:position_level, position_major_level: position_major_level))
        
        assignment1 = create(:assignment, company: company)
        assignment2 = create(:assignment, company: company)
        
        create(:position_assignment, position: position1, assignment: assignment1, assignment_type: 'required')
        create(:position_assignment, position: position2, assignment: assignment2, assignment_type: 'required')
        
        expect(described_class.calculate_phase(position_type)).to eq(2)
      end

      it 'returns 1 when not all positions have required assignments' do
        position1 = create(:position, position_type: position_type, position_level: position_level)
        position2 = create(:position, position_type: position_type, position_level: create(:position_level, position_major_level: position_major_level))
        
        assignment = create(:assignment, company: company)
        create(:position_assignment, position: position1, assignment: assignment, assignment_type: 'required')
        # position2 has no assignments
        
        expect(described_class.calculate_phase(position_type)).to eq(1)
      end
    end

    context 'Phase 3' do
      it 'returns 3 when employees have check-ins on required assignments' do
        position = create(:position, position_type: position_type, position_level: position_level)
        assignment = create(:assignment, company: company)
        create(:position_assignment, position: position, assignment: assignment, assignment_type: 'required')
        
        person = create(:person)
        teammate = create(:teammate, person: person, organization: company)
        employment_tenure = create(:employment_tenure, teammate: teammate, position: position, company: company)
        create(:assignment_check_in, teammate: teammate, assignment: assignment)
        
        expect(described_class.calculate_phase(position_type)).to eq(3)
      end

      it 'returns 2 when positions have tenures but no check-ins' do
        position = create(:position, position_type: position_type, position_level: position_level)
        assignment = create(:assignment, company: company)
        create(:position_assignment, position: position, assignment: assignment, assignment_type: 'required')
        
        person = create(:person)
        teammate = create(:teammate, person: person, organization: company)
        create(:employment_tenure, teammate: teammate, position: position, company: company)
        # No check-ins
        
        expect(described_class.calculate_phase(position_type)).to eq(2)
      end
    end

    context 'Phase 4' do
      it 'returns 4 when all required assignments have ability requirements' do
        position = create(:position, position_type: position_type, position_level: position_level)
        assignment = create(:assignment, company: company)
        create(:position_assignment, position: position, assignment: assignment, assignment_type: 'required')
        
        ability = create(:ability, organization: company)
        create(:assignment_ability, assignment: assignment, ability: ability, milestone_level: 1)
        
        expect(described_class.calculate_phase(position_type)).to eq(4)
      end

      it 'returns 3 when assignments exist but not all have abilities' do
        position = create(:position, position_type: position_type, position_level: position_level)
        assignment1 = create(:assignment, company: company)
        assignment2 = create(:assignment, company: company)
        create(:position_assignment, position: position, assignment: assignment1, assignment_type: 'required')
        create(:position_assignment, position: position, assignment: assignment2, assignment_type: 'required')
        
        ability = create(:ability, organization: company)
        create(:assignment_ability, assignment: assignment1, ability: ability, milestone_level: 1)
        # assignment2 has no abilities
        
        expect(described_class.calculate_phase(position_type)).to eq(3)
      end
    end

    context 'Phase 5' do
      it 'returns 5 when all abilities have at least 2 milestones defined' do
        position = create(:position, position_type: position_type, position_level: position_level)
        assignment = create(:assignment, company: company)
        create(:position_assignment, position: position, assignment: assignment, assignment_type: 'required')
        
        ability = create(:ability, 
          organization: company,
          milestone_1_description: 'Milestone 1',
          milestone_2_description: 'Milestone 2'
        )
        create(:assignment_ability, assignment: assignment, ability: ability, milestone_level: 1)
        
        expect(described_class.calculate_phase(position_type)).to eq(5)
      end

      it 'returns 4 when abilities exist but not all have 2 milestones' do
        position = create(:position, position_type: position_type, position_level: position_level)
        assignment = create(:assignment, company: company)
        create(:position_assignment, position: position, assignment: assignment, assignment_type: 'required')
        
        ability = create(:ability, 
          organization: company,
          milestone_1_description: 'Milestone 1'
          # Missing milestone_2_description
        )
        create(:assignment_ability, assignment: assignment, ability: ability, milestone_level: 1)
        
        expect(described_class.calculate_phase(position_type)).to eq(4)
      end
    end

    context 'Phase 6' do
      it 'returns 6 when all abilities have milestone attainments' do
        position = create(:position, position_type: position_type, position_level: position_level)
        assignment = create(:assignment, company: company)
        create(:position_assignment, position: position, assignment: assignment, assignment_type: 'required')
        
        ability = create(:ability, 
          organization: company,
          milestone_1_description: 'Milestone 1',
          milestone_2_description: 'Milestone 2'
        )
        create(:assignment_ability, assignment: assignment, ability: ability, milestone_level: 1)
        
        person = create(:person)
        teammate = create(:teammate, person: person, organization: company)
        create(:teammate_milestone, teammate: teammate, ability: ability, milestone_level: 1, certified_by: person)
        
        expect(described_class.calculate_phase(position_type)).to eq(6)
      end

      it 'returns 5 when abilities exist but not all have attainments' do
        position = create(:position, position_type: position_type, position_level: position_level)
        assignment = create(:assignment, company: company)
        create(:position_assignment, position: position, assignment: assignment, assignment_type: 'required')
        
        ability = create(:ability, 
          organization: company,
          milestone_1_description: 'Milestone 1',
          milestone_2_description: 'Milestone 2'
        )
        create(:assignment_ability, assignment: assignment, ability: ability, milestone_level: 1)
        # No teammate milestones
        
        expect(described_class.calculate_phase(position_type)).to eq(5)
      end
    end

    context 'Phase 7' do
      it 'returns 7 when all positions have eligibility_requirements_summary' do
        position1 = create(:position, position_type: position_type, position_level: position_level, eligibility_requirements_summary: 'Requirements')
        position2 = create(:position, position_type: position_type, position_level: create(:position_level, position_major_level: position_major_level), eligibility_requirements_summary: 'Requirements')
        
        assignment = create(:assignment, company: company)
        create(:position_assignment, position: position1, assignment: assignment, assignment_type: 'required')
        create(:position_assignment, position: position2, assignment: assignment, assignment_type: 'required')
        
        ability = create(:ability, 
          organization: company,
          milestone_1_description: 'Milestone 1',
          milestone_2_description: 'Milestone 2'
        )
        create(:assignment_ability, assignment: assignment, ability: ability, milestone_level: 1)
        
        person = create(:person)
        teammate = create(:teammate, person: person, organization: company)
        create(:teammate_milestone, teammate: teammate, ability: ability, milestone_level: 1, certified_by: person)
        
        expect(described_class.calculate_phase(position_type)).to eq(7)
      end

      it 'returns 6 when positions exist but not all have eligibility_requirements_summary' do
        position1 = create(:position, position_type: position_type, position_level: position_level, eligibility_requirements_summary: 'Requirements')
        position2 = create(:position, position_type: position_type, position_level: create(:position_level, position_major_level: position_major_level))
        # position2 has nil eligibility_requirements_summary
        
        assignment = create(:assignment, company: company)
        create(:position_assignment, position: position1, assignment: assignment, assignment_type: 'required')
        create(:position_assignment, position: position2, assignment: assignment, assignment_type: 'required')
        
        ability = create(:ability, 
          organization: company,
          milestone_1_description: 'Milestone 1',
          milestone_2_description: 'Milestone 2'
        )
        create(:assignment_ability, assignment: assignment, ability: ability, milestone_level: 1)
        
        person = create(:person)
        teammate = create(:teammate, person: person, organization: company)
        create(:teammate_milestone, teammate: teammate, ability: ability, milestone_level: 1, certified_by: person)
        
        expect(described_class.calculate_phase(position_type)).to eq(6)
      end
    end

    context 'Phase 8' do
      it 'returns 8 when ≥5% of entities updated in last 6 months' do
        position = create(:position, position_type: position_type, position_level: position_level, eligibility_requirements_summary: 'Requirements', updated_at: 3.months.ago)
        assignment = create(:assignment, company: company, updated_at: 2.months.ago)
        create(:position_assignment, position: position, assignment: assignment, assignment_type: 'required')
        
        ability = create(:ability, 
          organization: company,
          milestone_1_description: 'Milestone 1',
          milestone_2_description: 'Milestone 2',
          updated_at: 1.month.ago
        )
        create(:assignment_ability, assignment: assignment, ability: ability, milestone_level: 1)
        
        person = create(:person)
        teammate = create(:teammate, person: person, organization: company)
        create(:teammate_milestone, teammate: teammate, ability: ability, milestone_level: 1, certified_by: person)
        
        # Total entities: 3 (1 position, 1 assignment, 1 ability)
        # Updated in last 6 months: 3 (all)
        # Percentage: 100% >= 5%
        
        expect(described_class.calculate_phase(position_type)).to eq(8)
      end

      it 'returns 7 when <5% of entities updated in last 6 months' do
        position = create(:position, position_type: position_type, position_level: position_level, eligibility_requirements_summary: 'Requirements', updated_at: 7.months.ago)
        assignment = create(:assignment, company: company, updated_at: 8.months.ago)
        create(:position_assignment, position: position, assignment: assignment, assignment_type: 'required')
        
        ability = create(:ability, 
          organization: company,
          milestone_1_description: 'Milestone 1',
          milestone_2_description: 'Milestone 2',
          updated_at: 9.months.ago
        )
        create(:assignment_ability, assignment: assignment, ability: ability, milestone_level: 1)
        
        person = create(:person)
        teammate = create(:teammate, person: person, organization: company)
        create(:teammate_milestone, teammate: teammate, ability: ability, milestone_level: 1, certified_by: person)
        
        # Total entities: 3 (1 position, 1 assignment, 1 ability)
        # Updated in last 6 months: 0
        # Percentage: 0% < 5%
        
        expect(described_class.calculate_phase(position_type)).to eq(7)
      end
    end

    context 'Phase 9' do
      it 'returns 9 when ≥10% have published observations in last 6 months' do
        position = create(:position, position_type: position_type, position_level: position_level, eligibility_requirements_summary: 'Requirements', updated_at: 3.months.ago)
        assignment = create(:assignment, company: company, updated_at: 2.months.ago)
        create(:position_assignment, position: position, assignment: assignment, assignment_type: 'required')
        
        ability = create(:ability, 
          organization: company,
          milestone_1_description: 'Milestone 1',
          milestone_2_description: 'Milestone 2',
          updated_at: 1.month.ago
        )
        create(:assignment_ability, assignment: assignment, ability: ability, milestone_level: 1)
        
        person = create(:person)
        teammate = create(:teammate, person: person, organization: company)
        create(:teammate_milestone, teammate: teammate, ability: ability, milestone_level: 1, certified_by: person)
        
        observer = create(:person)
        observation = create(:observation, observer: observer, company: company, published_at: 1.month.ago)
        create(:observation_rating, observation: observation, rateable: ability, rating: 'agree')
        
        # Total entities: 3 (1 position, 1 assignment, 1 ability)
        # With published observations: 1 (ability)
        # Percentage: 33% >= 10%
        
        expect(described_class.calculate_phase(position_type)).to eq(9)
      end

      it 'returns 8 when <10% have published observations' do
        position = create(:position, position_type: position_type, position_level: position_level, eligibility_requirements_summary: 'Requirements', updated_at: 3.months.ago)
        assignment = create(:assignment, company: company, updated_at: 2.months.ago)
        create(:position_assignment, position: position, assignment: assignment, assignment_type: 'required')
        
        ability = create(:ability, 
          organization: company,
          milestone_1_description: 'Milestone 1',
          milestone_2_description: 'Milestone 2',
          updated_at: 1.month.ago
        )
        create(:assignment_ability, assignment: assignment, ability: ability, milestone_level: 1)
        
        person = create(:person)
        teammate = create(:teammate, person: person, organization: company)
        create(:teammate_milestone, teammate: teammate, ability: ability, milestone_level: 1, certified_by: person)
        
        # No observations
        
        # Total entities: 3 (1 position, 1 assignment, 1 ability)
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
      # Set up all phases to be met
      position = create(:position, position_type: position_type, position_level: position_level, eligibility_requirements_summary: 'Requirements', updated_at: 3.months.ago)
      assignment = create(:assignment, company: company, updated_at: 2.months.ago)
      create(:position_assignment, position: position, assignment: assignment, assignment_type: 'required')
      
      ability = create(:ability, 
        organization: company,
        milestone_1_description: 'Milestone 1',
        milestone_2_description: 'Milestone 2',
        updated_at: 1.month.ago
      )
      create(:assignment_ability, assignment: assignment, ability: ability, milestone_level: 1)
      
      person = create(:person)
      teammate = create(:teammate, person: person, organization: company)
      create(:teammate_milestone, teammate: teammate, ability: ability, milestone_level: 1, certified_by: person)
      
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
      position = create(:position, position_type: position_type, position_level: position_level)
      assignment = create(:assignment, company: company)
      create(:position_assignment, position: position, assignment: assignment, assignment_type: 'required')
      
      status = described_class.phase_status(position_type)
      expect(status[0]).to be true  # Phase 1 met
      expect(status[1]).to be false # Phase 2 not met (only one position, but need to check if all have assignments)
    end
  end
end

