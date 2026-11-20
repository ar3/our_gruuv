# frozen_string_literal: true

require "rails_helper"

RSpec.describe PossibleObservationConsults::FirstPassDiff do
  let(:organization) { create(:organization) }
  let(:creator) { create(:company_teammate, organization: organization, first_employed_at: 1.year.ago) }
  let(:pat) { create(:company_teammate, organization: organization, first_employed_at: 1.year.ago) }
  let(:alex) { create(:company_teammate, organization: organization, first_employed_at: 1.year.ago) }
  let(:consult) do
    create(
      :possible_observation_consult,
      organization: organization,
      creator_company_teammate: creator,
      first_pass_snapshot: {
        "version" => 1,
        "cue_annotations" => {
          "cues" => {
            "cue-1" => {
              "ogo_worthy" => true,
              "observer_company_teammate_id" => creator.id,
              "observee_company_teammate_id" => pat.id,
              "observee_company_teammate_ids" => [pat.id]
            }
          }
        }
      },
      cue_annotations: {
        "version" => 1,
        "cues" => {
          "cue-1" => {
            "ogo_worthy" => false,
            "observer_company_teammate_id" => creator.id,
            "observee_company_teammate_id" => alex.id,
            "observee_company_teammate_ids" => [alex.id]
          }
        }
      }
    )
  end

  it "reports worthiness flips and identity changes" do
    diff = described_class.call(consult: consult)

    expect(diff["worthiness_flip_count"]).to eq(1)
    expect(diff["identity_change_count"]).to eq(1)
    expect(diff["worthiness_flips"].first["cue_id"]).to eq("cue-1")
    expect(diff["identity_changes"].first["human_observee_company_teammate_ids"]).to eq([alex.id])
  end
end
