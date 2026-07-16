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

  def stub_slack_search(ok:, matches: [], error: nil, total: nil)
    body = if ok
      {
        "ok" => true,
        "messages" => {
          "total" => total || matches.size,
          "matches" => matches,
          "paging" => { "count" => matches.size, "total" => total || matches.size, "page" => 1, "pages" => 1 }
        }
      }
    else
      { "ok" => false, "error" => error || "invalid_auth" }
    end

    response = double(body: double(to_s: body.to_json))
    auth = double(get: response)
    allow(HTTP).to receive(:auth).with("Bearer xoxp-test-search-token").and_return(auth)
  end

  it "stores normalized raw messages and marks completed" do
    stub_slack_search(
      ok: true,
      matches: [
        {
          "iid" => "1",
          "team" => "T1",
          "channel" => { "id" => "C1", "name" => "eng" },
          "user" => "U1",
          "username" => "alex",
          "ts" => "1710000000.000100",
          "text" => "Great work Pat",
          "permalink" => "https://slack.example/p1"
        }
      ]
    )

    result = described_class.call(search: search)

    expect(result.success?).to be(true)
    search.reload
    expect(search.search_status).to eq("completed")
    expect(search.query).to include("<@USUBJECT99>")
    expect(search.query).to include("after:")
    expect(search.raw_messages_count).to eq(1)
    expect(search.raw_messages.first[:permalink]).to eq("https://slack.example/p1")
    expect(search.raw_messages.first[:channel_name]).to eq("eng")
  end

  it "marks failed when Slack returns an error" do
    stub_slack_search(ok: false, error: "missing_scope")

    result = described_class.call(search: search)

    expect(result.success?).to be(false)
    expect(search.reload.search_status).to eq("failed")
    expect(search.search_error).to include("missing_scope")
  end

  it "falls back to name search when subject has no Slack identity" do
    subject_slack.destroy!
    stub_slack_search(ok: true, matches: [])

    described_class.call(search: search)

    expect(search.reload.query).to include("Pat Subject")
    expect(search.query).not_to include("<@")
  end
end
