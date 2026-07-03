# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EngagementHealth::WeeklyRollupSnapshotter do
  let(:organization) { create(:organization, :company) }
  let(:week_ending_on) { Date.new(2026, 1, 11) }

  around do |example|
    Time.use_zone('UTC') { example.run }
  end

  it 'persists five category rollup rows per active teammate' do
    teammate = create(:company_teammate, organization: organization, first_employed_at: week_ending_on - 1.year)

    described_class.call(organization: organization, week_ending_on: week_ending_on)

    rollups = EngagementHealthWeeklyRollup.where(teammate: teammate, organization: organization, week_ending_on: week_ending_on)
    expect(rollups.count).to eq(EngagementHealth::CATEGORIES.size)
    expect(rollups.pluck(:category)).to match_array(EngagementHealth::CATEGORIES)
  end

  it 'snapshots historical OGO status using only events on or before that Sunday' do
    teammate = create(:company_teammate, organization: organization, first_employed_at: week_ending_on - 1.year)
    obs = create(:observation, observer: teammate.person, company: organization)
    obs.update!(published_at: week_ending_on.in_time_zone.end_of_day + 30.days)

    described_class.call(organization: organization, week_ending_on: week_ending_on)

    rollup = EngagementHealthWeeklyRollup.find_by!(
      teammate: teammate,
      organization: organization,
      week_ending_on: week_ending_on,
      category: EngagementHealth::CATEGORY_OGO_GIVEN
    )
    expect(rollup.status).to eq(EngagementHealth::NEEDS_ATTENTION)
  end

  it 'snapshots Healthy when an OGO was published within 30 days of that Sunday' do
    teammate = create(:company_teammate, organization: organization, first_employed_at: week_ending_on - 1.year)
    obs = create(:observation, observer: teammate.person, company: organization)
    obs.update!(published_at: week_ending_on.in_time_zone.end_of_day - 10.days)

    described_class.call(organization: organization, week_ending_on: week_ending_on)

    rollup = EngagementHealthWeeklyRollup.find_by!(
      teammate: teammate,
      organization: organization,
      week_ending_on: week_ending_on,
      category: EngagementHealth::CATEGORY_OGO_GIVEN
    )
    expect(rollup.status).to eq(EngagementHealth::HEALTHY)
  end

  it 'snapshots required_clarity using only check-ins on or before that Sunday' do
    teammate = create(:company_teammate, organization: organization, first_employed_at: week_ending_on - 1.year)
    tenure = create(
      :employment_tenure,
      teammate: teammate,
      company: organization,
      started_at: week_ending_on - 1.year,
      ended_at: nil
    )
    check_in = create(:position_check_in, :closed, teammate: teammate, employment_tenure: tenure)
    check_in.update_column(:official_check_in_completed_at, week_ending_on.in_time_zone.end_of_day + 5.days)

    described_class.call(organization: organization, week_ending_on: week_ending_on)

    rollup = EngagementHealthWeeklyRollup.find_by!(
      teammate: teammate,
      organization: organization,
      week_ending_on: week_ending_on,
      category: EngagementHealth::CATEGORY_REQUIRED_CLARITY
    )
    expect(rollup.status).to eq(EngagementHealth::NEEDS_ATTENTION)
  end
end
