# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EngagementHealth::WeeklyRollupTeammateScope do
  let(:organization) { create(:organization, :company) }
  let(:monday) { Date.new(2026, 4, 6) }
  let(:week_ending_on) { monday + 6.days }

  around do |example|
    Time.use_zone('UTC') { example.run }
  end

  describe '.active_teammate_ids' do
    it 'includes teammates employed for any part of the week' do
      employed_all_week = create(
        :company_teammate,
        organization: organization,
        first_employed_at: monday - 1.year,
        last_terminated_at: nil
      )
      terminated_mid_week = create(
        :company_teammate,
        organization: organization,
        first_employed_at: monday - 1.year,
        last_terminated_at: monday + 2.days
      )
      hired_mid_week = create(
        :company_teammate,
        organization: organization,
        first_employed_at: monday + 3.days,
        last_terminated_at: nil
      )
      terminated_before_week = create(
        :company_teammate,
        organization: organization,
        first_employed_at: monday - 1.year,
        last_terminated_at: monday - 1.day
      )
      hired_after_week = create(
        :company_teammate,
        organization: organization,
        first_employed_at: week_ending_on + 1.day,
        last_terminated_at: nil
      )

      ids = described_class.active_teammate_ids(organization: organization, week_ending_on: week_ending_on)

      expect(ids).to contain_exactly(employed_all_week.id, terminated_mid_week.id, hired_mid_week.id)
      expect(ids).not_to include(terminated_before_week.id, hired_after_week.id)
    end
  end
end
