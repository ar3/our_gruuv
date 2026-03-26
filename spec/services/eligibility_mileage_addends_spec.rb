require 'rails_helper'

RSpec.describe EligibilityMileageAddends do
  let(:company) { create(:organization) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, person: person, organization: company) }
  let(:title) { create(:title, company: company) }
  let(:position_level) { create(:position_level, position_major_level: title.position_major_level) }
  let(:position) { create(:position, title: title, position_level: position_level) }

  describe '.earned_for' do
    it 'returns empty addends when teammate has no milestones' do
      result = described_class.earned_for(teammate)
      expect(result[:addends]).to eq([])
      expect(result[:total]).to eq(0)
    end
  end

  describe '.required_for' do
    it 'returns empty addends when position has no milestone requirements' do
      result = described_class.required_for(position)
      expect(result[:addends]).to eq([])
      expect(result[:total]).to eq(0)
    end
  end
end
