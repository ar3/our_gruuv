# frozen_string_literal: true

require "rails_helper"

RSpec.describe PossibleObservationSlackSearches::RunSearchService do
  let(:organization) { create(:organization) }
  let(:creator_person) { create(:person) }
  let(:subject_person) { create(:person, full_name: "Pat Subject") }
  let(:creator) { create(:company_teammate, person: creator_person, organization: organization) }
  let(:subject) { create(:company_teammate, person: subject_person, organization: organization) }
  let!(:search_identity) { create(:teammate_identity, :slack_search, teammate: creator) }
  let!(:subject_slack) { create(:teammate_identity, :slack, teammate: subject, uid: "USUBJECT99") }
  let(:search) do
    create(
      :possible_observation_slack_search,
      organization: organization,
      creator_company_teammate: creator,
      subject_company_teammate: subject,
      window_days: 90
    )
  end

  before do
    create(:employment_tenure, teammate: creator, company: organization, started_at: 1.year.ago, ended_at: nil)
    create(:employment_tenure, teammate: subject, company: organization, started_at: 1.year.ago, ended_at: nil)
    creator.update!(first_employed_at: 1.year.ago)
    subject.update!(first_employed_at: 1.year.ago)
  end

  def match_hash(id:, text:, channel_id: "C1", ts: nil)
    {
      "iid" => id.to_s,
      "team" => "T1",
      "channel" => { "id" => channel_id, "name" => "eng" },
      "user" => "U1",
      "username" => "alex",
      "ts" => ts || "1710000000.000#{id}",
      "text" => text,
      "permalink" => "https://slack.example/p#{id}"
    }
  end

  def stub_slack_searches_by_query(responses_by_query)
    auth = double("auth")
    allow(HTTP).to receive(:auth).with("Bearer xoxp-test-search-token").and_return(auth)

    allow(auth).to receive(:get) do |_url, opts|
      query = opts.dig(:params, :query).to_s
      page = opts.dig(:params, :page).to_i
      pages =
        if query.start_with?("from:")
          responses_by_query.find { |prefix, _| prefix.start_with?("from:") }&.last
        else
          responses_by_query.find { |prefix, _| !prefix.start_with?("from:") && query.include?(prefix) }&.last
        end
      raise "Unexpected Slack query: #{query}" if pages.nil?

      matches = pages[page - 1] || []
      body = {
        "ok" => true,
        "messages" => {
          "total" => pages.flatten.size,
          "matches" => matches,
          "paging" => {
            "count" => matches.size,
            "total" => pages.flatten.size,
            "page" => page,
            "pages" => [pages.size, 1].max
          }
        }
      }
      double(body: double(to_s: body.to_json))
    end
  end

  it "runs about + from searches, dedupes overlaps, and stores both queries" do
    shared = match_hash(id: 1, text: "Great work Pat", ts: "1710000000.000100")
    stub_slack_searches_by_query(
      "<@USUBJECT99> after:" => [
        [shared],
        [match_hash(id: 2, text: "Pat again", ts: "1710000000.000200")]
      ],
      "from:<@USUBJECT99> after:" => [
        [shared, match_hash(id: 3, text: "I shipped the fix", channel_id: "C2", ts: "1710000000.000300")]
      ]
    )

    result = described_class.call(search: search)

    expect(result.success?).to be(true)
    search.reload
    expect(search.search_status).to eq("completed")
    expect(search.messages_count).to eq(3)
    expect(search.raw_results_file).to be_attached
    expect(search.raw_results["stored_in"]).to eq("active_storage")
    expect(search.raw_results["messages"]).to be_nil
    expect(search.raw_messages.map { |m| m[:text] }).to contain_exactly(
      "Great work Pat",
      "Pat again",
      "I shipped the fix"
    )
    expect(search.query).to include("about:")
    expect(search.query).to include("from:")
    expect(search.query).to include("<@USUBJECT99>")
    expect(search.query).to include("from:<@USUBJECT99>")
    kinds = search.search_queries.map { |q| q["kind"] || q[:kind] }
    expect(kinds).to include("about", "from")
  end

  it "marks failed when Slack returns an error" do
    auth = double("auth")
    allow(HTTP).to receive(:auth).and_return(auth)
    response = double(body: double(to_s: { "ok" => false, "error" => "missing_scope" }.to_json))
    allow(auth).to receive(:get).and_return(response)

    result = described_class.call(search: search)

    expect(result.success?).to be(false)
    expect(search.reload.search_status).to eq("failed")
    expect(search.search_error).to include("missing_scope")
  end

  it "falls back to name about-search only when subject has no Slack identity" do
    subject_slack.destroy!
    stub_slack_searches_by_query(
      "Pat Subject" => [[]]
    )

    described_class.call(search: search)

    expect(search.reload.query).to include("Pat Subject")
    expect(search.query).to include("about:")
    expect(search.query).not_to include("from:")
    expect(search.query).not_to include("<@")
    expect(search.search_queries.size).to eq(1)
  end
end
