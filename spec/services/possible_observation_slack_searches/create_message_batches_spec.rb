# frozen_string_literal: true

require "rails_helper"

RSpec.describe PossibleObservationSlackSearches::CreateMessageBatches do
  let(:organization) { create(:organization, :company) }
  let(:creator) { create(:company_teammate, :assigned_employee, organization: organization) }
  let(:subject_teammate) { create(:company_teammate, :assigned_employee, organization: organization) }

  def attach_messages(search, texts_with_ts)
    messages = texts_with_ts.map.with_index do |(text, ts), i|
      {
        "channel_id" => "C1",
        "channel_name" => "general",
        "user" => "U1",
        "username" => "alex",
        "ts" => ts,
        "text" => text,
        "permalink" => "https://example.slack.com/#{i}"
      }
    end
    search.raw_results_file.attach(
      io: StringIO.new(JSON.generate("version" => 1, "messages" => messages)),
      filename: "raw.json",
      content_type: "application/json"
    )
    search.update!(search_status: "completed", messages_count: messages.size)
  end

  it "creates newest-first batches of at most 500 filtered messages" do
    search = create(
      :possible_observation_slack_search,
      organization: organization,
      creator_company_teammate: creator,
      subject_company_teammate: subject_teammate
    )
    long = "x" * 50
    pairs = (1..501).map { |i| [long, format("%.6f", i)] }
    pairs << ["ok", "0.1"] # filtered out
    attach_messages(search, pairs)

    batches = described_class.call(search: search)

    expect(search.reload.filtered_messages_count).to eq(501)
    expect(batches.size).to eq(2)
    expect(batches.map(&:position)).to eq([1, 2])
    expect(batches.map(&:messages_count)).to eq([500, 1])
    expect(batches.first.newest_ts.to_f).to be > batches.first.oldest_ts.to_f
    expect(batches.first.display_label).to include("Consultation 1 of 2")
    expect(batches.first.display_label).to include("Newest 500")
    expect(batches.last.display_label).to include("Remaining 1")
  end

  it "creates no batches when every message is too short" do
    search = create(
      :possible_observation_slack_search,
      organization: organization,
      creator_company_teammate: creator,
      subject_company_teammate: subject_teammate
    )
    attach_messages(search, [["ok", "1.0"], ["hi", "2.0"]])

    expect(described_class.call(search: search)).to eq([])
    expect(search.reload.filtered_messages_count).to eq(0)
    expect(search.message_batches).to be_empty
  end
end
