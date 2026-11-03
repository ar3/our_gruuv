# frozen_string_literal: true

require "rails_helper"

RSpec.describe PossibleObservationSlackSearches::PromoteSlackPossibleObservation do
  let(:organization) { create(:organization, :company) }
  let(:creator) { create(:company_teammate, :assigned_employee, organization: organization) }
  let(:subject_teammate) { create(:company_teammate, :assigned_employee, organization: organization) }
  let(:assignment) { create(:assignment, company: organization) }
  let(:moment) do
    create(
      :slack_possible_observation,
      organization: organization,
      subject_company_teammate: subject_teammate,
      discoverer_company_teammate_ids: [creator.id],
      channel_id: "C123",
      message_ts: "1710000000.000100",
      payload: {
        "summary" => "Strong delivery",
        "quote" => "Pat crushed the launch",
        "confidence" => 0.9,
        "kind" => "kudos",
        "permalink" => "https://example.slack.com/p1",
        "responder_company_teammate_id" => creator.id,
        "suggested_rateable_type" => "Assignment",
        "suggested_rateable_id" => assignment.id,
        "suggested_rating" => "strongly_agree"
      }
    )
  end

  it "creates a draft observation with suggested rating and Slack trigger" do
    result = described_class.call(moment: moment, creator: creator)
    expect(result.ok?).to eq(true)
    expect(result.already_draft).to eq(false)

    observation = result.observation
    expect(observation).to be_draft
    expect(observation.story).to include("Pat crushed the launch")
    expect(observation.observation_trigger.trigger_source).to eq("slack")
    expect(observation.observation_trigger.trigger_data["channel_id"]).to eq("C123")
    expect(observation.observation_trigger.trigger_data["slack_possible_observation_id"]).to eq(moment.id)
    expect(observation.observees.map(&:teammate_id)).to eq([subject_teammate.id])
    rating = observation.observation_ratings.find_by(rateable: assignment)
    expect(rating.rating).to eq("strongly_agree")
  end

  it "returns the existing draft instead of creating another" do
    first = described_class.call(moment: moment, creator: creator)
    second = described_class.call(moment: moment, creator: creator)
    expect(second.ok?).to eq(true)
    expect(second.already_draft).to eq(true)
    expect(second.observation).to eq(first.observation)
    expect(Observation.where(observation_trigger: ObservationTrigger.where(trigger_source: "slack")).count).to eq(1)
  end

  it "rejects promote when a published OGO already exists for the message" do
    trigger = create(
      :observation_trigger,
      trigger_source: "slack",
      trigger_data: { "channel_id" => "C123", "message_ts" => "1710000000.000100" }
    )
    create(
      :observation,
      company: organization,
      observer: creator.person,
      observation_trigger: trigger,
      published_at: Time.current
    )

    result = described_class.call(moment: moment, creator: creator)
    expect(result.ok?).to eq(false)
    expect(result.error).to include("published OGO already exists")
  end
end
