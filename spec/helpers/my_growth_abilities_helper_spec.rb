# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MyGrowthAbilitiesHelper, type: :helper do
  describe '#my_growth_aggregate_mileage_earned_border_classes' do
    it 'returns warning when earned miles are below the current position mileage minimum' do
      result = helper.my_growth_aggregate_mileage_earned_border_classes(
        earned_miles: 2,
        current_minimum_miles: 10,
        target_minimum_miles: 20,
        target_position_defined: true
      )
      expect(result).to include('border-warning')
    end

    it 'returns info when current mileage is met but target minimum is not' do
      result = helper.my_growth_aggregate_mileage_earned_border_classes(
        earned_miles: 15,
        current_minimum_miles: 10,
        target_minimum_miles: 20,
        target_position_defined: true
      )
      expect(result).to include('border-info')
    end

    it 'returns success when both minimums are met' do
      result = helper.my_growth_aggregate_mileage_earned_border_classes(
        earned_miles: 25,
        current_minimum_miles: 10,
        target_minimum_miles: 20,
        target_position_defined: true
      )
      expect(result).to include('border-success')
    end

    it 'ignores target minimum when no target position is defined' do
      result = helper.my_growth_aggregate_mileage_earned_border_classes(
        earned_miles: 25,
        current_minimum_miles: 10,
        target_minimum_miles: 99,
        target_position_defined: false
      )
      expect(result).to include('border-success')
    end
  end

  describe '#my_growth_ability_row_card_border_classes' do
    let(:target_pos) { instance_double(Position, present?: true) }

    it 'returns warning when below current blueprint requirement' do
      result = helper.my_growth_ability_row_card_border_classes(
        earned_levels: [1],
        target_position: nil,
        cur: { minimum_milestone_level: 2 },
        tar: nil
      )
      expect(result).to include('border-warning')
    end

    it 'returns info when current is met but target is not (target position set)' do
      result = helper.my_growth_ability_row_card_border_classes(
        earned_levels: [2],
        target_position: target_pos,
        cur: { minimum_milestone_level: 2 },
        tar: { minimum_milestone_level: 3 }
      )
      expect(result).to include('border-info')
    end

    it 'returns success when both current and target requirements are met' do
      result = helper.my_growth_ability_row_card_border_classes(
        earned_levels: [3],
        target_position: target_pos,
        cur: { minimum_milestone_level: 2 },
        tar: { minimum_milestone_level: 3 }
      )
      expect(result).to include('border-success')
    end

    it 'returns success when no target requirement for this ability' do
      result = helper.my_growth_ability_row_card_border_classes(
        earned_levels: [1],
        target_position: target_pos,
        cur: { minimum_milestone_level: 1 },
        tar: nil
      )
      expect(result).to include('border-success')
    end
  end
end
