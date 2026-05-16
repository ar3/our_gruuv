# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Insights::OgScorecard::GoalsActiveAssociationWeekCounts do
  let(:company) { create(:company) }
  let(:monday) { Date.new(2026, 3, 2) }
  let(:week_starts) { [monday] }
  let(:week_end) { (monday + 6.days).in_time_zone.end_of_day }

  describe '#call' do
    it 'counts unique owners with active goals linked to an aspiration' do
      teammate = create(:teammate, organization: company, first_employed_at: monday - 1.year, last_terminated_at: nil)
      aspiration = create(:aspiration, company: company)
      goal = create(
        :goal,
        company: company,
        owner: teammate,
        creator: teammate,
        started_at: monday - 30.days,
        completed_at: nil,
        deleted_at: nil,
        goal_type: 'quantitative_key_result',
        most_likely_target_date: monday + 30.days
      )
      create(:goal_association, goal: goal, associable: aspiration)

      counts = described_class.call(company: company, week_starts: week_starts, associable_type: :aspiration)

      expect(counts[monday]).to eq(1)
    end

    it 'excludes goals completed before week end' do
      teammate = create(:teammate, organization: company, first_employed_at: monday - 1.year, last_terminated_at: nil)
      aspiration = create(:aspiration, company: company)
      goal = create(
        :goal,
        company: company,
        owner: teammate,
        creator: teammate,
        started_at: monday - 60.days,
        completed_at: monday - 14.days
      )
      create(:goal_association, goal: goal, associable: aspiration)

      counts = described_class.call(company: company, week_starts: week_starts, associable_type: :aspiration)

      expect(counts[monday]).to eq(0)
    end
  end
end
