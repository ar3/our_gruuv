# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Insights::OgScorecard::GruuvHealthWeekCounts do
  let(:company) { create(:company) }

  around do |example|
    Time.use_zone('UTC') { example.run }
  end

  describe '.call' do
    def counts_result(**kwargs)
      described_class.call(company: company, **kwargs)
    end

    def metric_key(category, status)
      described_class.metric_key(category, status)
    end

    it 'returns zeroed counts for every Gruuv Health metric key' do
      monday = Date.current.beginning_of_week(:monday)
      result = counts_result(week_starts: [monday])

      expect(result.counts.keys.size).to eq(EngagementHealth::CATEGORIES.size * EngagementHealth::STATUSES.size)
      EngagementHealth::CATEGORIES.each do |category|
        EngagementHealth::STATUSES.each do |status|
          key = metric_key(category, status)
          expect(result.counts[key]).to eq(monday => 0)
        end
      end
    end

    context 'current (in-progress) week' do
      let(:monday) { Date.current.beginning_of_week(:monday) }
      let(:week_starts) { [monday] }

      it 'reads category rollups from the live engagement_health_statuses cache' do
        teammate = create(:teammate, organization: company, first_employed_at: monday - 1.year, last_terminated_at: nil)
        EngagementHealthStatus.create!(
          teammate: teammate,
          organization: company,
          level: "category",
          category: EngagementHealth::CATEGORY_OGO_GIVEN,
          status: EngagementHealth::NEEDS_ATTENTION,
          inputs: {},
          computed_at: Time.current
        )

        result = counts_result(week_starts: week_starts)

        expect(result.backfill_enqueued).to be(false)
        expect(result.counts[metric_key(EngagementHealth::CATEGORY_OGO_GIVEN, EngagementHealth::NEEDS_ATTENTION)][monday]).to eq(1)
      end
    end

    context 'completed week' do
      let(:monday) { Date.new(2026, 1, 5) }
      let(:week_ending_on) { monday + 6.days }
      let(:week_starts) { [monday] }

      it 'reads from engagement_health_weekly_rollups' do
        teammate = create(:teammate, organization: company, first_employed_at: monday - 1.year, last_terminated_at: nil)
        EngagementHealth::CATEGORIES.each do |category|
          EngagementHealthWeeklyRollup.create!(
            teammate: teammate,
            organization: company,
            week_ending_on: week_ending_on,
            category: category,
            status: category == EngagementHealth::CATEGORY_OGO_GIVEN ? EngagementHealth::HEALTHY : EngagementHealth::NEEDS_ATTENTION,
            computed_at: Time.current
          )
        end

        result = counts_result(week_starts: week_starts)

        expect(result.backfill_enqueued).to be(false)
        expect(result.counts[metric_key(EngagementHealth::CATEGORY_OGO_GIVEN, EngagementHealth::HEALTHY)][monday]).to eq(1)
      end

      it 'enqueues a backfill job when rollup data is missing' do
        create(:teammate, organization: company, first_employed_at: monday - 1.year, last_terminated_at: nil)

        expect {
          result = counts_result(week_starts: week_starts)
          expect(result.backfill_enqueued).to be(true)
        }.to have_enqueued_job(EngagementHealthWeeklyRollupBackfillJob).with(company.id, [week_ending_on.iso8601])
      end

      it 'does not count healthy ogo_given from rollups when none exist for a historical week' do
        teammate = create(:teammate, organization: company, first_employed_at: monday - 1.year, last_terminated_at: nil)
        EngagementHealth::CATEGORIES.each do |category|
          EngagementHealthWeeklyRollup.create!(
            teammate: teammate,
            organization: company,
            week_ending_on: week_ending_on,
            category: category,
            status: category == EngagementHealth::CATEGORY_OGO_GIVEN ? EngagementHealth::NEEDS_ATTENTION : EngagementHealth::HEALTHY,
            computed_at: Time.current
          )
        end

        result = counts_result(week_starts: week_starts)

        expect(result.counts[metric_key(EngagementHealth::CATEGORY_OGO_GIVEN, EngagementHealth::HEALTHY)][monday]).to eq(0)
        expect(result.counts[metric_key(EngagementHealth::CATEGORY_OGO_GIVEN, EngagementHealth::NEEDS_ATTENTION)][monday]).to eq(1)
      end
    end
  end
end
