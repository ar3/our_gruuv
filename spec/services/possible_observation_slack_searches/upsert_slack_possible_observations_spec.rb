# frozen_string_literal: true

require "rails_helper"

RSpec.describe PossibleObservationSlackSearches::UpsertSlackPossibleObservations do
  let(:organization) { create(:organization, :company) }
  let(:creator) { create(:company_teammate, :assigned_employee, organization: organization) }
  let(:other_creator) { create(:company_teammate, :assigned_employee, organization: organization) }
  let(:subject_teammate) { create(:company_teammate, :assigned_employee, organization: organization) }
  let(:search) do
    record = create(
      :possible_observation_slack_search,
      organization: organization,
      creator_company_teammate: creator,
      subject_company_teammate: subject_teammate,
      search_status: "completed"
    )
    messages = [
      {
        "channel_id" => "Cpublic",
        "channel_name" => "general",
        "channel_is_private" => false,
        "channel_is_mpim" => false,
        "match_type" => "message",
        "ts" => "1710000000.000100",
        "text" => "Pat crushed it",
        "permalink" => "https://slack.example/p1",
        "user" => "U1",
        "username" => "alex"
      },
      {
        "channel_id" => "Gprivate",
        "channel_name" => "secret",
        "channel_is_private" => true,
        "channel_is_mpim" => false,
        "match_type" => "message",
        "ts" => "1710000000.000200",
        "text" => "private praise",
        "permalink" => "https://slack.example/p2",
        "user" => "U1",
        "username" => "alex"
      }
    ]
    record.raw_results_file.attach(
      io: StringIO.new(JSON.generate("version" => 1, "messages" => messages)),
      filename: "slack.json",
      content_type: "application/json"
    )
    record
  end
  let(:batch) do
    create(
      :possible_observation_slack_search_batch,
      possible_observation_slack_search: search,
      position: 1,
      message_keys: ["Cpublic|1710000000.000100", "Gprivate|1710000000.000200"],
      messages_count: 2
    )
  end

  def item(channel_id:, ts:, id: SecureRandom.uuid)
    {
      "id" => id,
      "channel_id" => channel_id,
      "ts" => ts,
      "quote" => "quote",
      "summary" => "summary",
      "confidence" => 0.9,
      "permalink" => "https://slack.example/x"
    }
  end

  it "creates durable public and private rows from extraction items" do
    expect do
      described_class.call(
        search: search,
        batch: batch,
        items: [
          item(channel_id: "Cpublic", ts: "1710000000.000100"),
          item(channel_id: "Gprivate", ts: "1710000000.000200")
        ]
      )
    end.to change(SlackPossibleObservation, :count).by(2)

    public_row = SlackPossibleObservation.find_by!(channel_id: "Cpublic", message_ts: "1710000000.000100")
    expect(public_row.visibility).to eq(SlackPossibleObservation::VISIBILITY_PUBLIC)
    expect(public_row.discoverer_ids).to eq([creator.id])
    expect(public_row.discovery_search_id_list).to eq([search.id])
    expect(public_row.subject_company_teammate).to eq(subject_teammate)

    private_row = SlackPossibleObservation.find_by!(channel_id: "Gprivate", message_ts: "1710000000.000200")
    expect(private_row.visibility).to eq(SlackPossibleObservation::VISIBILITY_PRIVATE_OR_DM)
  end

  it "does not duplicate when a second searcher finds the same message; appends discoverer" do
    described_class.call(
      search: search,
      batch: batch,
      items: [item(channel_id: "Cpublic", ts: "1710000000.000100")]
    )

    second_search = create(
      :possible_observation_slack_search,
      organization: organization,
      creator_company_teammate: other_creator,
      subject_company_teammate: subject_teammate,
      search_status: "completed"
    )
    second_search.raw_results_file.attach(
      io: StringIO.new(search.raw_results_file.download),
      filename: "slack2.json",
      content_type: "application/json"
    )
    second_batch = create(
      :possible_observation_slack_search_batch,
      possible_observation_slack_search: second_search,
      position: 1,
      message_keys: ["Cpublic|1710000000.000100"],
      messages_count: 1
    )

    expect do
      described_class.call(
        search: second_search,
        batch: second_batch,
        items: [item(channel_id: "Cpublic", ts: "1710000000.000100")]
      )
    end.not_to change(SlackPossibleObservation, :count)

    row = SlackPossibleObservation.find_by!(channel_id: "Cpublic", message_ts: "1710000000.000100")
    expect(row.discoverer_ids).to contain_exactly(creator.id, other_creator.id)
    expect(row.discovery_search_id_list).to contain_exactly(search.id, second_search.id)
  end

  it "refreshes payload on open rows when re-extracting" do
    described_class.call(
      search: search,
      batch: batch,
      items: [
        item(channel_id: "Cpublic", ts: "1710000000.000100").merge(
          "summary" => "Old summary",
          "suggested_rating" => "agree"
        )
      ]
    )
    row = SlackPossibleObservation.find_by!(channel_id: "Cpublic", message_ts: "1710000000.000100")
    expect(row.payload_hash[:summary]).to eq("Old summary")

    described_class.call(
      search: search,
      batch: batch,
      items: [
        item(channel_id: "Cpublic", ts: "1710000000.000100").merge(
          "summary" => "New summary",
          "suggested_rateable_type" => "Assignment",
          "suggested_rateable_name" => "Own launch",
          "suggested_rating" => "strongly_agree"
        )
      ]
    )

    expect(row.reload.payload_hash[:summary]).to eq("New summary")
    expect(row.payload_hash[:suggested_rating]).to eq("strongly_agree")
  end

  it "does not refresh payload for dismissed rows" do
    described_class.call(
      search: search,
      batch: batch,
      items: [item(channel_id: "Cpublic", ts: "1710000000.000100").merge("summary" => "Keep me")]
    )
    row = SlackPossibleObservation.find_by!(channel_id: "Cpublic", message_ts: "1710000000.000100")
    row.dismiss!(by: creator)

    described_class.call(
      search: search,
      batch: batch,
      items: [item(channel_id: "Cpublic", ts: "1710000000.000100").merge("summary" => "Should not win")]
    )

    expect(row.reload.payload_hash[:summary]).to eq("Keep me")
    expect(row).to be_dismissed
  end

  it "does not refresh payload when a published OGO already exists for the message" do
    described_class.call(
      search: search,
      batch: batch,
      items: [item(channel_id: "Cpublic", ts: "1710000000.000100").merge("summary" => "Published moment")]
    )
    trigger = create(
      :observation_trigger,
      trigger_source: "slack",
      trigger_data: { "channel_id" => "Cpublic", "message_ts" => "1710000000.000100" }
    )
    create(
      :observation,
      company: organization,
      observer: creator.person,
      observation_trigger: trigger,
      published_at: Time.current
    )

    described_class.call(
      search: search,
      batch: batch,
      items: [item(channel_id: "Cpublic", ts: "1710000000.000100").merge("summary" => "Should not win")]
    )

    row = SlackPossibleObservation.find_by!(channel_id: "Cpublic", message_ts: "1710000000.000100")
    expect(row.payload_hash[:summary]).to eq("Published moment")
  end
end
