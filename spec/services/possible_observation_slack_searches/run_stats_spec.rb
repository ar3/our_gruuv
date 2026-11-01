# frozen_string_literal: true

require "rails_helper"

RSpec.describe PossibleObservationSlackSearches::RunStats do
  let(:organization) { create(:organization, :company) }
  let(:creator) { create(:company_teammate, :assigned_employee, organization: organization) }
  let(:subject_teammate) { create(:company_teammate, :assigned_employee, organization: organization) }
  let(:search) do
    create(
      :possible_observation_slack_search,
      organization: organization,
      creator_company_teammate: creator,
      subject_company_teammate: subject_teammate,
      search_status: "completed",
      messages_count: 10,
      filtered_messages_count: 8,
      memo_hit_count: 3,
      memo_miss_count: 5
    )
  end

  it "counts reviewing / dismissed / published / not-worthy for the run" do
    create(
      :slack_possible_observation,
      organization: organization,
      subject_company_teammate: subject_teammate,
      discovery_search_ids: [search.id],
      discoverer_company_teammate_ids: [creator.id]
    )
    create(
      :slack_possible_observation,
      :dismissed,
      organization: organization,
      subject_company_teammate: subject_teammate,
      discovery_search_ids: [search.id],
      discoverer_company_teammate_ids: [creator.id]
    )
    published = create(
      :slack_possible_observation,
      organization: organization,
      subject_company_teammate: subject_teammate,
      discovery_search_ids: [search.id],
      discoverer_company_teammate_ids: [creator.id],
      channel_id: "Cpub",
      message_ts: "1710000000.009900"
    )
    trigger = create(
      :observation_trigger,
      trigger_source: "slack",
      trigger_data: { "channel_id" => published.channel_id, "message_ts" => published.message_ts }
    )
    create(:observation, company: organization, observer: creator.person, observation_trigger: trigger)

    stats = described_class.call(search: search)
    expect(stats.messages_consulted).to eq(8)
    expect(stats.messages_already_memoized).to eq(3)
    expect(stats.pogos_reviewing).to eq(1)
    expect(stats.pogos_dismissed).to eq(1)
    expect(stats.pogos_published).to eq(1)
    expect(stats.messages_not_ogo_worthy).to eq(5)
  end
end
