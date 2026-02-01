require 'rails_helper'

RSpec.describe AssignmentAbility, type: :model do
  let(:organization) { create(:organization) }
  let(:assignment) { create(:assignment, company: organization) }
  let(:ability) { create(:ability, company: organization) }
  let(:assignment_ability) { create(:assignment_ability, assignment: assignment, ability: ability) }

  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(assignment_ability).to be_valid
    end

    it 'requires an assignment' do
      assignment_ability.assignment = nil
      expect(assignment_ability).not_to be_valid
      expect(assignment_ability.errors[:assignment]).to include('must exist')
    end

    it 'requires an ability' do
      assignment_ability.ability = nil
      expect(assignment_ability).not_to be_valid
      expect(assignment_ability.errors[:ability]).to include('must exist')
    end

    it 'requires a milestone_level' do
      assignment_ability.milestone_level = nil
      expect(assignment_ability).not_to be_valid
      expect(assignment_ability.errors[:milestone_level]).to include("can't be blank")
    end

    it 'validates milestone_level is between 1 and 5' do
      assignment_ability.milestone_level = 0
      expect(assignment_ability).not_to be_valid
      expect(assignment_ability.errors[:milestone_level]).to include('must be greater than or equal to 1')

      assignment_ability.milestone_level = 6
      expect(assignment_ability).not_to be_valid
      expect(assignment_ability.errors[:milestone_level]).to include('must be less than or equal to 5')

      assignment_ability.milestone_level = 3
      expect(assignment_ability).to be_valid
    end

    it 'enforces unique assignment-ability combinations' do
      create(:assignment_ability, assignment: assignment, ability: ability)
      duplicate = build(:assignment_ability, assignment: assignment, ability: ability)
      
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:ability_id]).to include('has already been taken for this assignment')
    end

    it 'allows same ability for different assignments' do
      other_assignment = create(:assignment, company: organization, title: 'Different Assignment')
      create(:assignment_ability, assignment: assignment, ability: ability)
      other_assignment_ability = build(:assignment_ability, assignment: other_assignment, ability: ability)
      
      expect(other_assignment_ability).to be_valid
    end

    it 'allows same assignment for different abilities' do
      other_ability = create(:ability, company: organization)
      create(:assignment_ability, assignment: assignment, ability: ability)
      other_assignment_ability = build(:assignment_ability, assignment: assignment, ability: other_ability)
      
      expect(other_assignment_ability).to be_valid
    end
  end

  describe 'associations' do
    it 'belongs to an assignment' do
      expect(assignment_ability).to belong_to(:assignment)
    end

    it 'belongs to an ability' do
      expect(assignment_ability).to belong_to(:ability)
    end
  end

  describe 'organization scoping validation' do
    it 'validates assignment and ability belong to same organization' do
      other_organization = create(:organization)
      other_ability = create(:ability, company: other_organization)
      
      assignment_ability.ability = other_ability
      expect(assignment_ability).not_to be_valid
      expect(assignment_ability.errors[:ability]).to include('must belong to the same company as the assignment')
    end

    it 'allows assignment and ability from same organization' do
      expect(assignment_ability).to be_valid
    end
  end

  describe 'scopes' do
    let!(:assignment_ability_1) { create(:assignment_ability, assignment: assignment, ability: ability, milestone_level: 1) }
    let!(:assignment_ability_2) { create(:assignment_ability, assignment: assignment, ability: create(:ability, company: organization), milestone_level: 3) }
    let!(:assignment_ability_3) { create(:assignment_ability, assignment: assignment, ability: create(:ability, company: organization), milestone_level: 5) }

    describe '.for_assignment' do
      it 'returns assignment abilities for specific assignment' do
        other_assignment = create(:assignment, company: organization, title: 'Other Assignment')
        other_assignment_ability = create(:assignment_ability, assignment: other_assignment, ability: create(:ability, company: organization))

        result = AssignmentAbility.for_assignment(assignment)
        expect(result).to include(assignment_ability_1, assignment_ability_2, assignment_ability_3)
        expect(result).not_to include(other_assignment_ability)
      end
    end

    describe '.for_ability' do
      it 'returns assignment abilities for specific ability' do
        other_ability = create(:ability, company: organization)
        other_assignment_ability = create(:assignment_ability, assignment: assignment, ability: other_ability)

        result = AssignmentAbility.for_ability(ability)
        expect(result).to include(assignment_ability_1)
        expect(result).not_to include(assignment_ability_2, assignment_ability_3, other_assignment_ability)
      end
    end

    describe '.by_milestone_level' do
      it 'orders by milestone level ascending' do
        result = AssignmentAbility.by_milestone_level
        expect(result.to_a).to eq([assignment_ability_1, assignment_ability_2, assignment_ability_3])
      end
    end
  end

  describe 'instance methods' do
    describe '#milestone_level_display' do
      it 'returns formatted milestone level' do
        assignment_ability.milestone_level = 3
        expect(assignment_ability.milestone_level_display).to eq('Milestone 3')
      end
    end

    describe '#requirement_display' do
      it 'returns formatted requirement description' do
        assignment_ability.milestone_level = 2
        expect(assignment_ability.requirement_display).to eq("#{ability.name} - Milestone 2")
      end
    end
  end
end
