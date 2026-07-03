# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Insights::OgScorecard::MilestonesWeekCounts do
  let(:company) { create(:company) }
  let(:monday) { Date.new(2026, 4, 6) }
  let(:week_starts) { [monday] }

  around do |example|
    Time.use_zone('UTC') { example.run }
  end

  describe '#call' do
    it 'counts unique teammates and total milestones earned in the week' do
      teammate = create(:teammate, organization: company, first_employed_at: monday - 1.year)
      ability = create(:ability, company: company)
      wednesday = monday + 2.days
      create(:teammate_milestone, company_teammate: teammate, ability: ability, attained_at: wednesday)
      create(
        :teammate_milestone,
        company_teammate: teammate,
        ability: create(:ability, company: company),
        milestone_level: 2,
        attained_at: wednesday + 1.day
      )

      result = described_class.call(company: company, week_starts: week_starts)

      expect(result[:unique_teammates_milestone_this_week][monday]).to eq(1)
      expect(result[:milestones_earned_this_week][monday]).to eq(2)
    end

    it 'counts milestones in rolling 90 days ending Sunday' do
      teammate = create(:teammate, organization: company, first_employed_at: monday - 1.year)
      ability = create(:ability, company: company)
      sunday = monday + 6.days
      create(:teammate_milestone, company_teammate: teammate, ability: ability, attained_at: sunday - 45.days)
      create(
        :teammate_milestone,
        company_teammate: create(:teammate, organization: company, first_employed_at: monday - 1.year),
        ability: create(:ability, company: company),
        milestone_level: 2,
        attained_at: sunday - 100.days
      )

      result = described_class.call(company: company, week_starts: week_starts)

      expect(result[:unique_teammates_milestone_90_days][monday]).to eq(1)
      expect(result[:milestones_earned_90_days][monday]).to eq(1)
    end

    it 'counts cumulative milestones and unique teammates earned all-time through Sunday' do
      teammate = create(:teammate, organization: company, first_employed_at: monday - 1.year, last_terminated_at: nil)
      other_teammate = create(:teammate, organization: company, first_employed_at: monday - 1.year, last_terminated_at: nil)
      ability = create(:ability, company: company)
      sunday = monday + 6.days
      create(:teammate_milestone, company_teammate: teammate, ability: ability, attained_at: sunday - 200.days)
      create(
        :teammate_milestone,
        company_teammate: other_teammate,
        ability: create(:ability, company: company),
        milestone_level: 2,
        attained_at: sunday - 10.days
      )

      result = described_class.call(company: company, week_starts: week_starts)

      expect(result[:milestones_earned_all_time][monday]).to eq(2)
      expect(result[:unique_teammates_milestone_all_time][monday]).to eq(2)
    end

    it 'drops all-time teammate counts when no longer employed during a later week' do
      week_starts = [monday, monday + 7]
      teammate = create(
        :teammate,
        organization: company,
        first_employed_at: monday - 1.year,
        last_terminated_at: monday + 3.days
      )
      ability = create(:ability, company: company)
      create(:teammate_milestone, company_teammate: teammate, ability: ability, attained_at: monday + 1.day)

      result = described_class.call(company: company, week_starts: week_starts)

      expect(result[:unique_teammates_milestone_all_time][monday]).to eq(1)
      expect(result[:unique_teammates_milestone_all_time][monday + 7]).to eq(0)
      expect(result[:milestones_earned_all_time][monday + 7]).to eq(1)
    end

    it 'excludes milestones for abilities in other companies' do
      teammate = create(:teammate, organization: company, first_employed_at: monday - 1.year)
      other_ability = create(:ability, company: create(:company))
      create(:teammate_milestone, company_teammate: teammate, ability: other_ability, attained_at: monday + 2.days)

      result = described_class.call(company: company, week_starts: week_starts)

      expect(result[:milestones_earned_this_week][monday]).to eq(0)
    end
  end
end
