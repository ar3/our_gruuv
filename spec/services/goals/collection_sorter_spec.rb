require 'rails_helper'

RSpec.describe Goals::CollectionSorter do
  let(:organization) { create(:organization, :company) }
  let(:teammate) { create(:teammate, organization: organization) }

  def build_goal(title:, most_likely_target_date:)
    create(:goal,
      creator: teammate,
      owner: teammate,
      title: title,
      most_likely_target_date: most_likely_target_date)
  end

  describe '.call' do
    it 'sorts by most likely date then title ascending by default' do
      goal_b = build_goal(title: 'Bravo', most_likely_target_date: Date.new(2026, 6, 15))
      goal_a = build_goal(title: 'Alpha', most_likely_target_date: Date.new(2026, 6, 15))
      goal_c = build_goal(title: 'Charlie', most_likely_target_date: Date.new(2026, 7, 1))

      sorted = described_class.call([goal_c, goal_a, goal_b])

      expect(sorted).to eq([goal_a, goal_b, goal_c])
    end

    it 'sorts by most likely date descending with title tiebreaker ascending' do
      goal_b = build_goal(title: 'Bravo', most_likely_target_date: Date.new(2026, 6, 15))
      goal_a = build_goal(title: 'Alpha', most_likely_target_date: Date.new(2026, 6, 15))
      goal_c = build_goal(title: 'Charlie', most_likely_target_date: Date.new(2026, 7, 1))

      sorted = described_class.call([goal_a, goal_b, goal_c], sort: 'most_likely_target_date', direction: 'desc')

      expect(sorted).to eq([goal_c, goal_a, goal_b])
    end
  end
end
