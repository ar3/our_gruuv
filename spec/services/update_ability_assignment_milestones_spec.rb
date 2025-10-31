require 'rails_helper'

RSpec.describe UpdateAbilityAssignmentMilestones, type: :service do
  let(:company) { create(:organization, :company) }
  let!(:department) { create(:organization, :department, parent: company) }
  let(:ability) { create(:ability, organization: company) }
  let(:assignment1) { create(:assignment, company: company) }
  let(:assignment2) { create(:assignment, company: department) }
  let(:assignment3) { create(:assignment, company: company) }

  describe '#call' do
    context 'when creating new associations' do
      it 'creates new AssignmentAbility records for selected milestones' do
        milestone_data = {
          assignment1.id.to_s => '3',
          assignment2.id.to_s => '5',
          assignment3.id.to_s => ''
        }

        result = described_class.call(
          ability: ability,
          assignment_milestones: milestone_data
        )

        expect(result).to be_ok
        expect(ability.assignment_abilities.count).to eq(2)
        expect(ability.assignment_abilities.find_by(assignment: assignment1).milestone_level).to eq(3)
        expect(ability.assignment_abilities.find_by(assignment: assignment2).milestone_level).to eq(5)
        expect(ability.assignment_abilities.find_by(assignment: assignment3)).to be_nil
      end

      it 'ignores empty string values (no association)' do
        milestone_data = {
          assignment1.id.to_s => ''
        }

        result = described_class.call(
          ability: ability,
          assignment_milestones: milestone_data
        )

        expect(result).to be_ok
        expect(ability.assignment_abilities.count).to eq(0)
      end
    end

    context 'when updating existing associations' do
      let!(:existing_association) do
        create(:assignment_ability, :same_organization, ability: ability, assignment: assignment1, milestone_level: 2)
      end

      it 'updates existing AssignmentAbility records' do
        milestone_data = {
          assignment1.id.to_s => '4'
        }

        result = described_class.call(
          ability: ability,
          assignment_milestones: milestone_data
        )

        expect(result).to be_ok
        expect(ability.assignment_abilities.count).to eq(1)
        expect(existing_association.reload.milestone_level).to eq(4)
      end

      it 'deletes associations when set to empty string' do
        milestone_data = {
          assignment1.id.to_s => ''
        }

        result = described_class.call(
          ability: ability,
          assignment_milestones: milestone_data
        )

        expect(result).to be_ok
        expect(ability.assignment_abilities.count).to eq(0)
        expect { existing_association.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when mixing create, update, and delete' do
      let!(:existing_association) do
        create(:assignment_ability, :same_organization, ability: ability, assignment: assignment1, milestone_level: 2)
      end

      it 'handles all operations in a single transaction' do
        milestone_data = {
          assignment1.id.to_s => '5', # Update
          assignment2.id.to_s => '3', # Create
          assignment3.id.to_s => ''   # No change (no existing)
        }

        result = described_class.call(
          ability: ability,
          assignment_milestones: milestone_data
        )

        expect(result).to be_ok
        expect(ability.assignment_abilities.count).to eq(2)
        expect(existing_association.reload.milestone_level).to eq(5)
        expect(ability.assignment_abilities.find_by(assignment: assignment2).milestone_level).to eq(3)
        expect(ability.assignment_abilities.find_by(assignment: assignment3)).to be_nil
      end
    end

    context 'when validating milestone levels' do
      it 'validates milestone level is between 1 and 5' do
        milestone_data = {
          assignment1.id.to_s => '6'
        }

        result = described_class.call(
          ability: ability,
          assignment_milestones: milestone_data
        )

        expect(result).not_to be_ok
        expect(result.error).to be_present
      end

      it 'accepts 0 to delete association' do
        # Create an existing association first
        create(:assignment_ability, :same_organization, ability: ability, assignment: assignment1, milestone_level: 3)
        
        milestone_data = {
          assignment1.id.to_s => '0'
        }

        result = described_class.call(
          ability: ability,
          assignment_milestones: milestone_data
        )

        expect(result).to be_ok
        expect(ability.assignment_abilities.find_by(assignment: assignment1)).to be_nil
      end
    end

    context 'when assignment and ability belong to different organizations' do
      let(:other_company) { create(:organization, :company) }
      let(:other_assignment) { create(:assignment, company: other_company) }

      it 'returns error for cross-organization associations' do
        milestone_data = {
          other_assignment.id.to_s => '3'
        }

        result = described_class.call(
          ability: ability,
          assignment_milestones: milestone_data
        )

        expect(result).not_to be_ok
        expect(result.error).to be_present
      end
    end

    context 'when assignment is in company hierarchy' do
      it 'allows association with assignment in department' do
        milestone_data = {
          assignment2.id.to_s => '3' # assignment2 is in department, which is in company hierarchy
        }

        result = described_class.call(
          ability: ability,
          assignment_milestones: milestone_data
        )

        expect(result).to be_ok
        expect(ability.assignment_abilities.find_by(assignment: assignment2).milestone_level).to eq(3)
      end
    end

    context 'with empty milestone data' do
      it 'succeeds and leaves no associations' do
        result = described_class.call(
          ability: ability,
          assignment_milestones: {}
        )

        expect(result).to be_ok
        expect(ability.assignment_abilities.count).to eq(0)
      end
    end
  end
end

