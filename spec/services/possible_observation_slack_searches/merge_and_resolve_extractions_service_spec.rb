# frozen_string_literal: true

require "rails_helper"

RSpec.describe PossibleObservationSlackSearches::MergeAndResolveExtractionsService do
  let(:organization) { create(:organization) }
  let(:creator) { create(:company_teammate, organization: organization) }
  let(:subject_person) { create(:person, full_name: "Pat Subject") }
  let(:subject) { create(:company_teammate, person: subject_person, organization: organization) }
  let(:speaker_person) { create(:person, full_name: "Alex Speaker") }
  let(:speaker) { create(:company_teammate, person: speaker_person, organization: organization) }
  let(:search) do
    create(
      :possible_observation_slack_search,
      :completed,
      organization: organization,
      creator_company_teammate: creator,
      subject_company_teammate: subject
    )
  end

  before do
    create(:teammate_identity, :slack, teammate: speaker, uid: "UOBS")
    [creator, subject, speaker].each do |tm|
      create(:employment_tenure, teammate: tm, company: organization, started_at: 1.year.ago, ended_at: nil)
      tm.update!(first_employed_at: 1.year.ago)
    end
  end

  it "defaults subject to the search subject and resolves speaker by Slack uid" do
    items = described_class.call(
      search: search,
      raw_items_by_chunk: [
        [
          {
            "kind" => "kudos",
            "summary" => "Pat crushed it",
            "short_quote" => "great job",
            "full_quote" => "Pat did a great job on the launch.",
            "quote" => "Pat did a great job on the launch.",
            "speaker_label" => "alex",
            "recipient_label" => "Pat",
            "channel_id" => "C123",
            "ts" => "1710000000.000100",
            "permalink" => "https://example.slack.com/p1",
            "slack_user_id" => "UOBS"
          }
        ]
      ]
    )

    expect(items.size).to eq(1)
    expect(items.first["responder_company_teammate_id"]).to eq(speaker.id)
    expect(items.first["subject_company_teammate_id"]).to eq(subject.id)
    expect(items.first["include"]).to be(true)
    expect(items.first["channel_id"]).to eq("C123")
  end

  it "keeps validated suggestion fields from the catalog" do
    items = described_class.call(
      search: search,
      context_catalog: {
        "Assignment" => { 11 => "Own launch" },
        "Ability" => {},
        "Aspiration" => {},
        "Goal" => { 22 => "Close deals" }
      },
      raw_items_by_chunk: [
        [
          {
            "kind" => "kudos",
            "summary" => "Suggested: Exceptional example of Assignment Own launch. Pat crushed it",
            "short_quote" => "great job",
            "full_quote" => "Pat did a great job on the launch.",
            "quote" => "Pat did a great job on the launch.",
            "speaker_label" => "alex",
            "recipient_label" => "Pat",
            "channel_id" => "C123",
            "ts" => "1710000000.000100",
            "permalink" => "https://example.slack.com/p1",
            "slack_user_id" => "UOBS",
            "suggested_rateable_type" => "Assignment",
            "suggested_rateable_id" => 11,
            "suggested_rating" => "strongly_agree",
            "suggested_goal_id" => 22
          }
        ]
      ]
    )

    expect(items.first["suggested_rateable_type"]).to eq("Assignment")
    expect(items.first["suggested_rateable_id"]).to eq(11)
    expect(items.first["suggested_rating"]).to eq("strongly_agree")
    expect(items.first["suggested_goal_id"]).to eq(22)
  end
end
