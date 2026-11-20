# frozen_string_literal: true

require "rails_helper"

RSpec.describe PossibleObservationConsults::BatchCreateDraftObservationsService do
  let(:organization) { create(:organization) }
  let(:creator_person) { create(:person, full_name: "Casey Creator") }
  let(:creator) { create(:company_teammate, person: creator_person, organization: organization) }
  let(:observer_person) { create(:person, full_name: "Alex Observer") }
  let(:observer_teammate) { create(:company_teammate, person: observer_person, organization: organization) }
  let(:subject_a_person) { create(:person, full_name: "Kayla One") }
  let(:subject_a) { create(:company_teammate, person: subject_a_person, organization: organization) }
  let(:subject_b_person) { create(:person, full_name: "Nicole Two") }
  let(:subject_b) { create(:company_teammate, person: subject_b_person, organization: organization) }
  let(:consult) do
    create(
      :possible_observation_consult,
      organization: organization,
      creator_company_teammate: creator,
      people_status: "confirmed",
      extraction_status: "completed",
      extractions: {
        "version" => PossibleObservationConsult::EXTRACTIONS_VERSION,
        "items" => [base_item]
      }
    )
  end

  def base_item(overrides = {})
    {
      "id" => "cue-1",
      "include" => true,
      "kind" => "kudos",
      "quote" => "Shout out to Kayla and Nicole.",
      "responder_company_teammate_id" => observer_teammate.id,
      "subject_company_teammate_id" => subject_a.id,
      "subject_company_teammate_ids" => [subject_a.id],
      "suggested_rateables" => []
    }.merge(overrides)
  end

  before do
    [creator, observer_teammate, subject_a, subject_b].each do |tm|
      create(:employment_tenure, teammate: tm, company: organization, started_at: 1.year.ago, ended_at: nil)
      tm.update!(first_employed_at: 1.year.ago)
    end
  end

  it "creates a draft with every multi observee" do
    consult.replace_extraction_items!([
      base_item(
        "subject_company_teammate_id" => subject_a.id,
        "subject_company_teammate_ids" => [subject_a.id, subject_b.id]
      )
    ])

    result = described_class.call(consult: consult.reload, creator: creator)
    expect(result).to be_ok
    expect(result.value[:created]).to eq(1)
    expect(result.value[:errors]).to be_empty

    observation = Observation.last
    expect(observation).to be_draft
    expect(observation.observer).to eq(observer_person)
    expect(observation.observed_teammates).to contain_exactly(subject_a, subject_b)
  end

  it "creates a draft with no observees for intentional team blank" do
    consult.replace_extraction_items!([
      base_item(
        "subject_company_teammate_id" => nil,
        "subject_company_teammate_ids" => []
      )
    ])

    result = described_class.call(consult: consult.reload, creator: creator)
    expect(result).to be_ok
    expect(result.value[:created]).to eq(1)
    expect(result.value[:errors]).to be_empty

    observation = Observation.last
    expect(observation).to be_draft
    expect(observation.observees).to be_empty
  end

  it "requires an observer" do
    consult.replace_extraction_items!([
      base_item("responder_company_teammate_id" => nil)
    ])

    result = described_class.call(consult: consult.reload, creator: creator)
    expect(result).to be_ok
    expect(result.value[:created]).to eq(0)
    expect(result.value[:errors].join).to include("observer")
  end
end
