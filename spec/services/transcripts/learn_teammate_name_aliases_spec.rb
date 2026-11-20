# frozen_string_literal: true

require "rails_helper"

RSpec.describe Transcripts::LearnTeammateNameAliases do
  let(:organization) { create(:organization) }
  let(:creator) { create(:company_teammate, organization: organization, first_employed_at: 1.year.ago) }
  let(:casey_person) { create(:person, first_name: "Casey", last_name: "Jones", preferred_name: "Casey") }
  let(:casey) { create(:company_teammate, person: casey_person, organization: organization, first_employed_at: 1.year.ago) }
  let(:consult) do
    create(
      :possible_observation_consult,
      organization: organization,
      creator_company_teammate: creator,
      speaker_map: {
        "version" => 1,
        "labels" => {
          "CJ" => {
            "raw_label" => "CJ",
            "company_teammate_id" => casey.id,
            "manual" => true
          }
        }
      },
      cue_annotations: {
        "version" => 1,
        "cues" => {
          "cue-1" => {
            "ogo_worthy" => true,
            "observer_label" => "CJ",
            "observer_company_teammate_id" => casey.id,
            "observee_labels" => ["Bobby"],
            "observee_company_teammate_id" => casey.id,
            "observee_company_teammate_ids" => [casey.id]
          }
        }
      }
    )
  end

  it "learns speaker and observee labels as aliases" do
    result = described_class.call(consult: consult, created_by: creator)

    expect(result[:learned]).to be >= 1
    expect(casey.name_aliases.pluck(:normalized_name)).to include("cj")
    expect(casey.name_aliases.pluck(:normalized_name)).to include("bobby")
  end
end
