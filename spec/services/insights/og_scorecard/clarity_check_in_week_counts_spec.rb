# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Insights::OgScorecard::ClarityCheckInWeekCounts do
  let(:company) { create(:company) }
  let(:monday) { Date.new(2026, 3, 2) }
  let(:week_starts) { [monday, monday + 7] }

  around do |example|
    Time.use_zone('UTC') { example.run }
  end

  describe '#call' do
    it 'counts unique teammates who finalized a clarity check-in during the week' do
      teammate = create(:teammate, organization: company, first_employed_at: monday - 1.year, last_terminated_at: nil)
      tenure = create(:employment_tenure, company_teammate: teammate, company: company, started_at: monday - 1.year)
      create(
        :position_check_in,
        :closed,
        teammate: teammate,
        employment_tenure: tenure,
        official_check_in_completed_at: monday.to_time + 12.hours
      )

      result = described_class.call(company: company, week_starts: [monday])

      expect(result[:unique_teammates_check_in_finalized_this_week][monday]).to eq(1)
      expect(result[:unique_teammates_check_in_finalized_all_time][monday]).to eq(1)
    end

    it 'shows zero for this week when finalization happened only in an earlier week' do
      teammate = create(:teammate, organization: company, first_employed_at: monday - 1.year, last_terminated_at: nil)
      tenure = create(:employment_tenure, company_teammate: teammate, company: company, started_at: monday - 1.year)
      create(
        :position_check_in,
        :closed,
        teammate: teammate,
        employment_tenure: tenure,
        official_check_in_completed_at: monday.to_time + 12.hours
      )

      result = described_class.call(company: company, week_starts: week_starts)

      expect(result[:unique_teammates_check_in_finalized_this_week][monday + 7]).to eq(0)
      expect(result[:unique_teammates_check_in_finalized_all_time][monday + 7]).to eq(1)
    end

    it 'drops all-time counts when a teammate is no longer employed during a later week' do
      teammate = create(
        :teammate,
        organization: company,
        first_employed_at: monday - 1.year,
        last_terminated_at: monday + 3.days
      )
      tenure = create(:employment_tenure, company_teammate: teammate, company: company, started_at: monday - 1.year)
      create(
        :position_check_in,
        :closed,
        teammate: teammate,
        employment_tenure: tenure,
        official_check_in_completed_at: monday.to_time + 12.hours
      )

      result = described_class.call(company: company, week_starts: week_starts)

      expect(result[:unique_teammates_check_in_finalized_all_time][monday]).to eq(1)
      expect(result[:unique_teammates_check_in_finalized_all_time][monday + 7]).to eq(0)
    end

    it 'deduplicates teammates with multiple finalized check-ins in the same week' do
      teammate = create(:teammate, organization: company, first_employed_at: monday - 1.year, last_terminated_at: nil)
      tenure = create(:employment_tenure, company_teammate: teammate, company: company, started_at: monday - 1.year)
      assignment = create(:assignment, company: company)
      create(
        :position_check_in,
        :closed,
        teammate: teammate,
        employment_tenure: tenure,
        official_check_in_completed_at: monday.to_time + 12.hours
      )
      create(
        :assignment_check_in,
        :officially_completed,
        teammate: teammate,
        assignment: assignment,
        official_check_in_completed_at: (monday + 2.days).to_time + 12.hours
      )

      result = described_class.call(company: company, week_starts: [monday])

      expect(result[:unique_teammates_check_in_finalized_this_week][monday]).to eq(1)
    end
  end
end
