require 'rails_helper'

RSpec.describe PositionsHelper, type: :helper do
  describe '#milestone_level_display' do
    it 'returns "Demonstrated" for level 1' do
      expect(helper.milestone_level_display(1)).to eq('Demonstrated')
    end

    it 'returns "Advanced" for level 2' do
      expect(helper.milestone_level_display(2)).to eq('Advanced')
    end

    it 'returns "Expert" for level 3' do
      expect(helper.milestone_level_display(3)).to eq('Expert')
    end

    it 'returns "Coach" for level 4' do
      expect(helper.milestone_level_display(4)).to eq('Coach')
    end

    it 'returns "Industry-Recognized" for level 5' do
      expect(helper.milestone_level_display(5)).to eq('Industry-Recognized')
    end

    it 'returns "Unknown" for invalid level' do
      expect(helper.milestone_level_display(0)).to eq('Unknown')
      expect(helper.milestone_level_display(6)).to eq('Unknown')
    end
  end
end

