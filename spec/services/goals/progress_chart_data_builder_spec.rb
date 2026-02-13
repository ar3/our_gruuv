# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Goals::ProgressChartDataBuilder, type: :service do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, person: person, organization: organization) }
  let(:creator_teammate) { CompanyTeammate.find(teammate.id) }

  let(:goal) do
    create(:goal,
      creator: creator_teammate,
      owner: creator_teammate,
      started_at: 8.weeks.ago,
      earliest_target_date: 4.weeks.from_now.to_date,
      most_likely_target_date: 8.weeks.from_now.to_date,
      latest_target_date: 12.weeks.from_now.to_date
    )
  end

  describe '#call' do
    context 'when goal has no target dates' do
      let(:goal_no_dates) do
        create(:goal,
          creator: creator_teammate,
          owner: creator_teammate,
          started_at: 1.week.ago,
          earliest_target_date: nil,
          most_likely_target_date: nil,
          latest_target_date: nil
        )
      end

      it 'returns nil' do
        expect(described_class.call(goal: goal_no_dates)).to be_nil
      end
    end

    context 'when goal has no started_at' do
      let(:goal_not_started) do
        g = create(:goal, creator: creator_teammate, owner: creator_teammate, most_likely_target_date: 1.month.from_now.to_date)
        g.update_column(:started_at, nil)
        g
      end

      it 'returns nil' do
        expect(described_class.call(goal: goal_not_started)).to be_nil
      end
    end

    context 'when goal has target dates and started_at' do
      it 'returns hash with categories and series' do
        result = described_class.call(goal: goal)
        expect(result).to be_a(Hash)
        expect(result[:categories]).to be_an(Array)
        expect(result[:series]).to be_an(Array)
      end

      it 'includes area bands (behind, on schedule, ahead) and actual confidence' do
        result = described_class.call(goal: goal)
        names = result[:series].map { |s| s[:name] }
        expect(names).to include('Behind schedule', 'On schedule band', 'Ahead band', 'Ahead of schedule', 'Actual confidence')
      end

      it 'includes check-in points when goal has check-ins' do
        create(:goal_check_in, goal: goal, check_in_week_start: 2.weeks.ago.beginning_of_week(:monday), confidence_percentage: 70, confidence_reporter: person)
        result = described_class.call(goal: goal)
        actual_series = result[:series].find { |s| s[:name] == 'Actual confidence' }
        expect(actual_series).to be_present
        expect(actual_series[:data].size).to eq(1)
        expect(actual_series[:data].first[1]).to eq(70)
      end

      it 'uses Mondays from start to chart end for categories' do
        result = described_class.call(goal: goal)
        expect(result[:categories].first).to be_present
        expect(result[:categories].size).to be >= 1
      end
    end
  end
end
