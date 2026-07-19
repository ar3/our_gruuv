# frozen_string_literal: true

require "rails_helper"

RSpec.describe PossibleObservationSlackSearches::BatchCreateDraftObservationsService do
  let(:organization) { create(:organization) }
  let(:creator_person) { create(:person, full_name: "Casey Creator") }
  let(:creator) { create(:company_teammate, person: creator_person, organization: organization) }
  let(:observer_person) { create(:person, full_name: "Alex Observer") }
  let(:observer_teammate) { create(:company_teammate, person: observer_person, organization: organization) }
  let(:subject_person) { create(:person, full_name: "Pat Subject") }
  let(:subject) { create(:company_teammate, person: subject_person, organization: organization) }
  let(:search) do
    create(
      :possible_observation_slack_search,
      organization: organization,
      creator_company_teammate: creator,
      subject_company_teammate: subject
    )
  end
  let(:batch) do
    create(
      :possible_observation_slack_search_batch,
      :extracted,
      possible_observation_slack_search: search
    ).tap do |b|
      items = b.extraction_items.map(&:to_h).map(&:stringify_keys)
      items[0]["responder_company_teammate_id"] = observer_teammate.id
      items[0]["subject_company_teammate_id"] = subject.id
      items[0]["include"] = true
      b.replace_extraction_items!(items)
    end
  end

  before do
    create(:employment_tenure, teammate: creator, company: organization, started_at: 1.year.ago, ended_at: nil)
    creator.update!(first_employed_at: 1.year.ago)
    create(:employment_tenure, teammate: observer_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    observer_teammate.update!(first_employed_at: 1.year.ago)
    create(:employment_tenure, teammate: subject, company: organization, started_at: 1.year.ago, ended_at: nil)
    subject.update!(first_employed_at: 1.year.ago)
  end

  it "creates a draft OGO with creator ≠ observer, trigger, and observee" do
    expect do
      result = described_class.call(batch: batch, creator: creator)
      expect(result).to be_ok
      expect(result.value[:created]).to eq(1)
      expect(result.value[:errors]).to be_empty
    end.to change(Observation, :count).by(1)
       .and change(ObservationTrigger, :count).by(1)

    observation = Observation.last
    expect(observation).to be_draft
    expect(observation.observer).to eq(observer_person)
    expect(observation.creator_company_teammate).to eq(creator)
    expect(observation.created_as_type).to eq(Observation::CREATED_AS_SLACK_SOURCE)
    expect(observation.observation_type).to eq("kudos")
    expect(observation.observed_teammates).to contain_exactly(subject)
    expect(observation.observation_ratings).to be_empty
    expect(observation.story).to include("Sourced from Slack")
    expect(observation.story).to include("Link to message:")
    expect(observation.observation_trigger.trigger_source).to eq("slack")
    expect(observation.observation_trigger.trigger_type).to eq("ogo_source_search")
    expect(observation.observation_trigger.trigger_data["channel_id"]).to eq("C123")
    expect(observation.observation_trigger.trigger_data["message_ts"]).to eq("1710000000.000100")
    expect(observation.observation_trigger.trigger_data["possible_observation_slack_search_id"]).to eq(search.id)
    expect(observation.source_slack_search).to eq(search)
    expect(observation).to be_slack_sourced

    batch.reload
    expect(batch.extraction_items.first[:observation_id]).to eq(observation.id)
  end

  it "is idempotent when observation_id is already present" do
    described_class.call(batch: batch, creator: creator)
    expect do
      result = described_class.call(batch: batch.reload, creator: creator)
      expect(result).to be_ok
      expect(result.value[:created]).to eq(0)
      expect(result.value[:skipped_already]).to eq(1)
    end.not_to change(Observation, :count)
  end

  it "skips rows that are not included" do
    items = batch.extraction_items.map(&:to_h).map(&:stringify_keys)
    items[0]["include"] = false
    batch.replace_extraction_items!(items)

    result = described_class.call(batch: batch.reload, creator: creator)
    expect(result).to be_ok
    expect(result.value[:created]).to eq(0)
    expect(Observation.count).to eq(0)
  end

  it "sets goal_id when suggested_goal_id is valid for the subject" do
    goal = create(:goal, company: organization, owner: subject, creator: creator, title: "Ship it")
    items = batch.extraction_items.map(&:to_h).map(&:stringify_keys)
    items[0]["suggested_goal_id"] = goal.id
    batch.replace_extraction_items!(items)

    result = described_class.call(batch: batch.reload, creator: creator)
    expect(result).to be_ok
    expect(Observation.last.goal_id).to eq(goal.id)
  end
end
