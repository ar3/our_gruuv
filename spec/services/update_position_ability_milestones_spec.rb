# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UpdatePositionAbilityMilestones, type: :service do
  let(:organization) { create(:organization) }
  let(:title) { create(:title, company: organization) }
  let(:position_level) { create(:position_level, position_major_level: title.position_major_level) }
  let(:position) { create(:position, title: title, position_level: position_level) }
  let(:ability1) { create(:ability, company: organization) }
  let(:ability2) { create(:ability, company: organization) }
  let(:ability3) { create(:ability, company: organization) }

  describe '#call' do
    context 'when creating new associations' do
      it 'creates new PositionAbility records for selected milestones' do
        milestone_data = {
          ability1.id.to_s => '3',
          ability2.id.to_s => '5',
          ability3.id.to_s => ''
        }

        result = described_class.call(
          position: position,
          ability_milestones: milestone_data
        )

        expect(result).to be_ok
        expect(position.position_abilities.count).to eq(2)
        expect(position.position_abilities.find_by(ability: ability1).milestone_level).to eq(3)
        expect(position.position_abilities.find_by(ability: ability2).milestone_level).to eq(5)
        expect(position.position_abilities.find_by(ability: ability3)).to be_nil
      end

      it 'ignores empty string values (no association)' do
        milestone_data = {
          ability1.id.to_s => ''
        }

        result = described_class.call(
          position: position,
          ability_milestones: milestone_data
        )

        expect(result).to be_ok
        expect(position.position_abilities.count).to eq(0)
      end
    end

    context 'when updating existing associations' do
      let!(:existing_association) do
        create(:position_ability, :same_organization, position: position, ability: ability1, milestone_level: 2)
      end

      it 'updates existing PositionAbility records' do
        milestone_data = {
          ability1.id.to_s => '4'
        }

        result = described_class.call(
          position: position,
          ability_milestones: milestone_data
        )

        expect(result).to be_ok
        expect(position.position_abilities.count).to eq(1)
        expect(existing_association.reload.milestone_level).to eq(4)
      end

      it 'deletes associations when set to 0' do
        milestone_data = {
          ability1.id.to_s => '0'
        }

        result = described_class.call(
          position: position,
          ability_milestones: milestone_data
        )

        expect(result).to be_ok
        expect(position.position_abilities.count).to eq(0)
        expect { existing_association.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when mixing create, update, and delete' do
      let!(:existing_association) do
        create(:position_ability, :same_organization, position: position, ability: ability1, milestone_level: 2)
      end

      it 'handles all operations in a single transaction' do
        milestone_data = {
          ability1.id.to_s => '5', # Update
          ability2.id.to_s => '3', # Create
          ability3.id.to_s => ''   # No change (no existing)
        }

        result = described_class.call(
          position: position,
          ability_milestones: milestone_data
        )

        expect(result).to be_ok
        expect(position.position_abilities.find_by(ability: ability1).milestone_level).to eq(5)
        expect(position.position_abilities.find_by(ability: ability2).milestone_level).to eq(3)
        expect(position.position_abilities.find_by(ability: ability3)).to be_nil
      end
    end

    context 'when validating milestone level' do
      it 'returns error for invalid milestone level' do
        milestone_data = {
          ability1.id.to_s => '6'
        }

        result = described_class.call(
          position: position,
          ability_milestones: milestone_data
        )

        expect(result).not_to be_ok
        expect(result.error).to include('Invalid milestone level')
      end
    end

    context 'when validating organization scoping' do
      let(:other_organization) { create(:organization) }
      let(:ability_other_org) { create(:ability, company: other_organization) }

      it 'returns error when ability belongs to different company' do
        milestone_data = {
          ability_other_org.id.to_s => '3'
        }

        result = described_class.call(
          position: position,
          ability_milestones: milestone_data
        )

        expect(result).not_to be_ok
        expect(result.error).to include('Ability must belong to the same company')
      end
    end

    context 'when ability_milestones is empty' do
      it 'succeeds and leaves position_abilities unchanged' do
        create(:position_ability, position: position, ability: ability1, milestone_level: 2)

        result = described_class.call(
          position: position,
          ability_milestones: {}
        )

        expect(result).to be_ok
        expect(position.position_abilities.count).to eq(1)
      end
    end
  end
end
