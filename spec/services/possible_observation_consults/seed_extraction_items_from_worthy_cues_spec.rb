# frozen_string_literal: true

require "rails_helper"

RSpec.describe PossibleObservationConsults::SeedExtractionItemsFromWorthyCues do
  let(:organization) { create(:organization) }
  let(:observer) { create(:company_teammate, organization: organization, first_employed_at: 1.year.ago) }
  let(:observee) { create(:company_teammate, organization: organization, first_employed_at: 1.year.ago) }
  let(:consult) do
    create(
      :possible_observation_consult,
      organization: organization,
      creator_company_teammate: observer,
      source_text: "unused",
      speaker_map: {
        "version" => 1,
        "labels" => {
          "Alex" => { "certainty" => "certain", "company_teammate_id" => observer.id }
        }
      },
      cue_annotations: {
        "version" => 1,
        "moments" => [
          {
            "id" => "cue-1",
            "speaker_label" => "Alex",
            "text" => "Shout out to Pat for the launch.",
            "start" => "00:01:00.000",
            "start_ms" => 60_000
          },
          {
            "id" => "cue-2",
            "speaker_label" => "Alex",
            "text" => "Logistics only.",
            "start" => "00:02:00.000",
            "start_ms" => 120_000
          }
        ],
        "cues" => {
          "cue-1" => {
            "cue_status" => "ogo_worthy",
            "ogo_worthy" => true,
            "observer_company_teammate_id" => observer.id,
            "observee_company_teammate_id" => observee.id,
            "observee_labels" => ["Pat"]
          },
          "cue-2" => {
            "cue_status" => "ignore",
            "ogo_worthy" => false
          }
        }
      }
    )
  end

  it "builds one Step 3 item per OGO-worthy cue with frozen quote and identities" do
    items = described_class.call(consult: consult)
    expect(items.size).to eq(1)
    item = items.first
    expect(item["id"]).to eq("cue-1")
    expect(item["cue_id"]).to eq("cue-1")
    expect(item["quote"]).to eq("Shout out to Pat for the launch.")
    expect(item["responder_company_teammate_id"]).to eq(observer.id)
    expect(item["subject_company_teammate_id"]).to eq(observee.id)
    expect(item["suggested_rateables"]).to eq([])
  end
end
