# frozen_string_literal: true

require "rails_helper"

RSpec.describe PossibleObservationConsults::MergeAndResolveExtractionsService do
  let(:organization) { create(:organization) }
  let(:pat_person) { create(:person, first_name: "Pat", last_name: "Subject") }
  let(:pat) { create(:company_teammate, person: pat_person, organization: organization, first_employed_at: 1.year.ago) }
  let(:alex_able_person) { create(:person, first_name: "Alex", last_name: "Able") }
  let(:alex_able) { create(:company_teammate, person: alex_able_person, organization: organization, first_employed_at: 1.year.ago) }
  let(:alex_baker_person) { create(:person, first_name: "Alex", last_name: "Baker") }
  let(:alex_baker) { create(:company_teammate, person: alex_baker_person, organization: organization, first_employed_at: 1.year.ago) }

  before do
    allow_any_instance_of(Transcripts::TeammateResolverService).to receive(:bedrock_configured?).and_return(false)
  end

  def raw_item(speaker_label:, recipient_label: "Pat", subject_id: pat.id)
    {
      "kind" => "kudos",
      "summary" => "Pat crushed it",
      "full_quote" => "Pat did a great job.",
      "quote" => "Pat did a great job.",
      "speaker_label" => speaker_label,
      "recipient_label" => recipient_label,
      "subject_company_teammate_id" => subject_id,
      "confidence" => 0.9
    }
  end

  it "selects a unique observer and stores no observer alternates" do
    items = described_class.call(
      organization: organization,
      confirmed_teammates: [pat],
      raw_items_by_chunk: [[raw_item(speaker_label: "Pat")]]
    )

    expect(items.size).to eq(1)
    expect(items.first["responder_company_teammate_id"]).to eq(pat.id)
    expect(items.first["observer_unknown"]).to eq(false)
    expect(items.first["observer_alternates"]).to eq([])
    expect(items.first["observee_alternates"]).to eq([])
  end

  it "keeps a best-guess observer and other Alexes as clickable observer alternates" do
    alex_able
    alex_baker

    items = described_class.call(
      organization: organization,
      confirmed_teammates: [pat],
      raw_items_by_chunk: [[raw_item(speaker_label: "Alex")]]
    )

    item = items.first
    expect(item["observer_unknown"]).to eq(true)
    expect([alex_able.id, alex_baker.id]).to include(item["responder_company_teammate_id"])
    expect(item["observer_alternates"].map { |alt| alt["company_teammate_id"] }).to include(
      ([alex_able.id, alex_baker.id] - [item["responder_company_teammate_id"]]).first
    )
  end
end
