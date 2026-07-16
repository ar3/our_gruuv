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

  def match_hash(id:, text:)
    {
      "iid" => id.to_s,
      "team" => "T1",
      "channel" => { "id" => "C1", "name" => "eng" },
      "user" => "U1",
      "username" => "alex",
      "ts" => "1710000000.000#{id}",
      "text" => text,
      "permalink" => "https://slack.example/p#{id}"
    }
  end

  def stub_paginated_slack_search(pages:)
    auth = double("auth")
    allow(HTTP).to receive(:auth).with("Bearer xoxp-test-search-token").and_return(auth)

    pages.each_with_index do |matches, index|
      page_number = index + 1
      body = {
        "ok" => true,
        "messages" => {
          "total" => pages.flatten.size,
          "matches" => matches,
          "paging" => {
            "count" => matches.size,
            "total" => pages.flatten.size,
            "page" => page_number,
            "pages" => pages.size
          }
        }
      }
      response = double(body: double(to_s: body.to_json))
      expect(auth).to receive(:get).with(
        "https://slack.com/api/search.messages",
        hash_including(params: hash_including(page: page_number, count: 100))
      ).and_return(response)
    end
  end

  it "paginates all pages, attaches raw JSON, and keeps only metadata in the DB row" do
    stub_paginated_slack_search(
      pages: [
        [match_hash(id: 1, text: "Great work Pat")],
        [match_hash(id: 2, text: "Pat again")]
      ]
    )

    result = described_class.call(search: search)

    expect(result.success?).to be(true)
    search.reload
    expect(search.search_status).to eq("completed")
    expect(search.messages_count).to eq(2)
    expect(search.raw_results_file).to be_attached
    expect(search.raw_results["stored_in"]).to eq("active_storage")
    expect(search.raw_results["messages"]).to be_nil
    expect(search.raw_messages.map { |m| m[:text] }).to eq(["Great work Pat", "Pat again"])
    expect(search.query).to include("<@USUBJECT99>")
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

  it "falls back to name search when subject has no Slack identity" do
    subject_slack.destroy!
    stub_paginated_slack_search(pages: [[]])

    described_class.call(search: search)

    expect(search.reload.query).to include("Pat Subject")
    expect(search.query).not_to include("<@")
  end
end
