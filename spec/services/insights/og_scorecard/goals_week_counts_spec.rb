# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Insights::OgScorecard::GoalsWeekCounts do
  let(:company) { create(:company) }
  let(:monday) { Date.new(2026, 4, 6) }
  let(:week_starts) { [monday] }

  around do |example|
    Time.use_zone('UTC') { example.run }
  end

  describe '#call' do
    it 'counts unique teammates with an active owned goal as of Sunday' do
      teammate = create(:teammate, organization: company, first_employed_at: monday - 1.year)
      other = create(:teammate, organization: company, first_employed_at: monday - 1.year)
      create(
        :goal,
        company: company,
        owner: teammate,
        creator: teammate,
        started_at: monday - 30.days,
        completed_at: nil,
        deleted_at: nil
      )
      create(
        :goal,
        company: company,
        owner: other,
        creator: other,
        started_at: monday - 30.days,
        completed_at: monday + 5.days
      )

      result = described_class.call(company: company, week_starts: week_starts)

      expect(result[:unique_teammates_active_goal][monday]).to eq(1)
    end

    it 'counts teammates with a goal check-in created during the week on goals active Sunday' do
      teammate = create(:teammate, organization: company, first_employed_at: monday - 1.year)
      goal = create(
        :goal,
        company: company,
        owner: teammate,
        creator: teammate,
        started_at: monday - 30.days,
        completed_at: nil,
        deleted_at: nil
      )
      create(:goal_check_in, goal: goal, created_at: monday + 2.days)

      result = described_class.call(company: company, week_starts: week_starts)

      expect(result[:unique_teammates_goal_check_in_this_week][monday]).to eq(1)
    end

    it 'excludes check-ins outside the week or on goals not active as of Sunday' do
      teammate = create(:teammate, organization: company, first_employed_at: monday - 1.year)
      other = create(:teammate, organization: company, first_employed_at: monday - 1.year)
      active_goal = create(
        :goal,
        company: company,
        owner: teammate,
        creator: teammate,
        started_at: monday - 30.days,
        completed_at: nil,
        deleted_at: nil
      )
      completed_goal = create(
        :goal,
        company: company,
        owner: other,
        creator: other,
        started_at: monday - 30.days,
        completed_at: monday + 3.days
      )
      outside_week_goal = create(
        :goal,
        company: company,
        owner: other,
        creator: other,
        started_at: monday - 30.days,
        completed_at: nil,
        deleted_at: nil
      )
      create(:goal_check_in, goal: active_goal, created_at: monday + 2.days)
      create(:goal_check_in, goal: outside_week_goal, created_at: monday - 1.day)
      create(:goal_check_in, goal: completed_goal, created_at: monday + 2.days)

      result = described_class.call(company: company, week_starts: week_starts)

      expect(result[:unique_teammates_goal_check_in_this_week][monday]).to eq(1)
    end

    it 'counts unique owners with a completion in rolling 90 days ending Sunday' do
      teammate = create(:teammate, organization: company, first_employed_at: monday - 1.year)
      sunday = monday + 6.days
      create(
        :goal,
        company: company,
        owner: teammate,
        creator: teammate,
        started_at: sunday - 120.days,
        completed_at: sunday - 45.days
      )
      create(
        :goal,
        company: company,
        owner: create(:teammate, organization: company, first_employed_at: monday - 1.year),
        creator: teammate,
        started_at: sunday - 200.days,
        completed_at: sunday - 100.days
      )

      result = described_class.call(company: company, week_starts: week_starts)

      expect(result[:unique_teammates_completed_goal_90_days][monday]).to eq(1)
    end

    it 'counts unique owners whose goal was live for any day in the trailing 90 days' do
      sunday = monday + 6.days
      still_active = create(:teammate, organization: company, first_employed_at: monday - 1.year)
      completed_in_window = create(:teammate, organization: company, first_employed_at: monday - 1.year)
      started_in_window = create(:teammate, organization: company, first_employed_at: monday - 1.year)
      completed_before_window = create(:teammate, organization: company, first_employed_at: monday - 1.year)
      deleted_owner = create(:teammate, organization: company, first_employed_at: monday - 1.year)

      create(
        :goal,
        company: company,
        owner: still_active,
        creator: still_active,
        started_at: sunday - 30.days,
        completed_at: nil,
        deleted_at: nil
      )
      create(
        :goal,
        company: company,
        owner: completed_in_window,
        creator: completed_in_window,
        started_at: sunday - 120.days,
        completed_at: sunday - 45.days,
        deleted_at: nil
      )
      create(
        :goal,
        company: company,
        owner: started_in_window,
        creator: started_in_window,
        started_at: sunday - 10.days,
        completed_at: nil,
        deleted_at: nil
      )
      create(
        :goal,
        company: company,
        owner: completed_before_window,
        creator: completed_before_window,
        started_at: sunday - 200.days,
        completed_at: sunday - 100.days,
        deleted_at: nil
      )
      create(
        :goal,
        company: company,
        owner: deleted_owner,
        creator: deleted_owner,
        started_at: sunday - 30.days,
        completed_at: nil,
        deleted_at: sunday - 5.days
      )

      result = described_class.call(company: company, week_starts: week_starts)

      expect(result[:unique_teammates_active_goal_90_days][monday]).to eq(3)
    end

    it 'excludes goals owned by other companies' do
      teammate = create(:teammate, organization: company, first_employed_at: monday - 1.year)
      other_company = create(:company)
      create(
        :goal,
        company: other_company,
        owner: teammate,
        creator: teammate,
        started_at: monday - 30.days,
        completed_at: nil,
        deleted_at: nil
      )

      result = described_class.call(company: company, week_starts: week_starts)

      expect(result[:unique_teammates_active_goal][monday]).to eq(0)
    end
  end
end
