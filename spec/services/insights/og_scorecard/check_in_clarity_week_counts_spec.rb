# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Insights::OgScorecard::CheckInClarityWeekCounts do
  let(:company) { create(:company) }
  let(:monday) { Date.new(2026, 3, 2) }
  let(:week_starts) { [monday] }
  let(:reference_time) { (monday + 6.days).in_time_zone.end_of_day }

  describe '#call' do
    it 'counts teammate with no required check-ins as clear' do
      reference_time = (monday + 6.days).in_time_zone.end_of_day
      teammate = create(
        :teammate,
        organization: company,
        first_employed_at: reference_time - 1.year,
        last_terminated_at: nil
      )
      preloaded = Insights::OgScorecard::CheckInDataPreloader.new(company).load
      preloaded[:aspiration_ids] = []
      preloaded[:employment_tenures] = []
      preloaded[:assignment_tenures] = []
      preloaded[:position_finalized_at] = {}
      preloaded[:assignment_finalized_at] = {}
      preloaded[:aspiration_finalized_at] = {}
      preloaded[:teammates] = [[teammate.id, teammate.first_employed_at, teammate.last_terminated_at]]

      result = described_class.call(company: company, week_starts: week_starts, preloaded_data: preloaded)

      expect(result[:all_check_ins_clear][monday]).to eq(1)
      expect(result[:all_check_ins_blurred][monday]).to eq(0)
      expect(result[:all_check_ins_obscured][monday]).to eq(0)
    end

    it 'buckets teammate with old position check-in as obscured' do
      teammate = create(:teammate, organization: company, first_employed_at: monday - 1.year, last_terminated_at: nil)
      tenure = create(:employment_tenure, company_teammate: teammate, company: company, started_at: monday - 1.year)
      create(
        :position_check_in,
        :closed,
        teammate: teammate,
        employment_tenure: tenure,
        official_check_in_completed_at: reference_time - 120.days
      )

      result = described_class.call(company: company, week_starts: week_starts)

      expect(result[:all_check_ins_obscured][monday]).to eq(1)
      expect(result[:all_check_ins_clear][monday]).to eq(0)
    end
  end
end
