# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PositionAbility, type: :model do
  let(:organization) { create(:organization) }
  let(:title) { create(:title, company: organization) }
  let(:position_level) { create(:position_level, position_major_level: title.position_major_level) }
  let(:position) { create(:position, title: title, position_level: position_level) }
  let(:ability) { create(:ability, company: organization) }
  let(:position_ability) { create(:position_ability, position: position, ability: ability) }

  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(position_ability).to be_valid
    end

    it 'requires a position' do
      position_ability.position = nil
      expect(position_ability).not_to be_valid
      expect(position_ability.errors[:position]).to include('must exist')
    end

    it 'requires an ability' do
      position_ability.ability = nil
      expect(position_ability).not_to be_valid
      expect(position_ability.errors[:ability]).to include('must exist')
    end

    it 'requires a milestone_level' do
      position_ability.milestone_level = nil
      expect(position_ability).not_to be_valid
      expect(position_ability.errors[:milestone_level]).to include("can't be blank")
    end

    it 'validates milestone_level is between 1 and 5' do
      position_ability.milestone_level = 0
      expect(position_ability).not_to be_valid
      expect(position_ability.errors[:milestone_level]).to include('must be greater than or equal to 1')

      position_ability.milestone_level = 6
      expect(position_ability).not_to be_valid
      expect(position_ability.errors[:milestone_level]).to include('must be less than or equal to 5')

      position_ability.milestone_level = 3
      expect(position_ability).to be_valid
    end

    it 'enforces unique position-ability combinations' do
      create(:position_ability, position: position, ability: ability)
      duplicate = build(:position_ability, position: position, ability: ability)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:ability_id]).to include('has already been taken for this position')
    end

    it 'allows same ability for different positions' do
      other_position = create(:position, title: title, position_level: create(:position_level, position_major_level: title.position_major_level, level: '1.2'))
      create(:position_ability, position: position, ability: ability)
      other_position_ability = build(:position_ability, position: other_position, ability: ability)

      expect(other_position_ability).to be_valid
    end
  end

  describe 'associations' do
    it 'belongs to a position' do
      expect(position_ability).to belong_to(:position)
    end

    it 'belongs to an ability' do
      expect(position_ability).to belong_to(:ability)
    end
  end

  describe 'organization scoping validation' do
    it 'is invalid when ability belongs to a different company than position' do
      other_company = create(:organization)
      ability_other = create(:ability, company: other_company)
      pa = build(:position_ability, position: position, ability: ability_other)

      expect(pa).not_to be_valid
      expect(pa.errors[:ability]).to include('must belong to the same company as the position')
    end

    it 'is valid when ability and position belong to the same company' do
      expect(position_ability).to be_valid
    end
  end

  describe '#milestone_level_display' do
    it 'returns formatted string' do
      position_ability.milestone_level = 3
      expect(position_ability.milestone_level_display).to eq('Milestone 3')
    end
  end

  describe '#requirement_display' do
    it 'returns ability name and milestone level display' do
      position_ability.ability.name = 'Ruby'
      position_ability.milestone_level = 2
      expect(position_ability.requirement_display).to eq('Ruby - Milestone 2')
    end
  end
end
