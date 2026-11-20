# frozen_string_literal: true

require "rails_helper"

RSpec.describe PossibleObservationConsults::PersistPeopleMapService do
  let(:organization) { create(:organization) }
  let(:creator) { create(:company_teammate, organization: organization, first_employed_at: 1.year.ago) }
  let(:kayla) { create(:company_teammate, organization: organization, first_employed_at: 1.year.ago) }
  let(:nicole) { create(:company_teammate, organization: organization, first_employed_at: 1.year.ago) }
  let(:consult) do
    create(
      :possible_observation_consult,
      organization: organization,
      creator_company_teammate: creator,
      cue_annotations: {
        "version" => 1,
        "moments" => [
          {
            "id" => "cue-1",
            "speaker_label" => "Alex",
            "text" => "Shout out to Kayla and Nicole."
          }
        ],
        "cues" => {
          "cue-1" => {
            "ogo_worthy" => true,
            "cue_status" => "ogo_worthy",
            "observer_company_teammate_id" => creator.id,
            "observee_company_teammate_id" => kayla.id,
            "observee_company_teammate_ids" => [kayla.id, nicole.id]
          }
        }
      }
    )
  end

  it "keeps multi observee ids when the select stays on multi" do
    described_class.call(
      consult: consult,
      speaker_map_params: {},
      cue_annotations_params: {
        "cue-1" => {
          "ogo_worthy" => "1",
          "observer_company_teammate_id" => creator.id,
          "observee_company_teammate_id" => "multi",
          "observee_company_teammate_ids" => [kayla.id, nicole.id]
        }
      }
    )

    row = consult.reload.cue_annotation_rows["cue-1"]
    expect(row[:observee_company_teammate_ids]).to contain_exactly(kayla.id, nicole.id)
    expect(row[:observee_company_teammate_id]).to eq(kayla.id)
    expect(row[:observee_certainty]).to eq("certain")
  end

  it "clears observees for team/group blank" do
    described_class.call(
      consult: consult,
      speaker_map_params: {},
      cue_annotations_params: {
        "cue-1" => {
          "ogo_worthy" => "1",
          "observer_company_teammate_id" => creator.id,
          "observee_company_teammate_id" => "",
          "observee_company_teammate_ids" => [kayla.id, nicole.id]
        }
      }
    )

    row = consult.reload.cue_annotation_rows["cue-1"]
    expect(row[:observee_company_teammate_ids]).to eq([])
    expect(row[:observee_company_teammate_id]).to be_nil
  end

  it "collapses to one observee when a single teammate is chosen" do
    described_class.call(
      consult: consult,
      speaker_map_params: {},
      cue_annotations_params: {
        "cue-1" => {
          "ogo_worthy" => "1",
          "observer_company_teammate_id" => creator.id,
          "observee_company_teammate_id" => nicole.id.to_s,
          "observee_company_teammate_ids" => [kayla.id, nicole.id]
        }
      }
    )

    row = consult.reload.cue_annotation_rows["cue-1"]
    expect(row[:observee_company_teammate_ids]).to eq([nicole.id])
    expect(row[:observee_company_teammate_id]).to eq(nicole.id)
  end
end
