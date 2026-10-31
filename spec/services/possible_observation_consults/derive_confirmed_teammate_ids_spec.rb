# frozen_string_literal: true

require "rails_helper"

RSpec.describe PossibleObservationConsults::DeriveConfirmedTeammateIds do
  let(:organization) { create(:organization) }
  let(:observer) { create(:company_teammate, organization: organization, first_employed_at: 1.year.ago) }
  let(:observee) { create(:company_teammate, organization: organization, first_employed_at: 1.year.ago) }
  let(:consult) do
    create(
      :possible_observation_consult,
      organization: organization,
      creator_company_teammate: observer,
      source_text: <<~VTT,
        WEBVTT

        1
        00:01:00.000 --> 00:01:01.000
        Alex: Great work on the launch.

        2
        00:01:02.000 --> 00:01:03.000
        Alex: Thanks everyone on the team.
      VTT
      speaker_map: {
        "version" => 1,
        "labels" => {
          "Alex" => { "certainty" => "certain", "company_teammate_id" => observer.id }
        }
      },
      cue_annotations: {
        "version" => 1,
        "cues" => {
          "cue-1" => {
            "cue_status" => "ogo_worthy",
            "observee_certainty" => "certain",
            "observee_company_teammate_id" => observee.id
          },
          "cue-2" => {
            "cue_status" => "ignore",
            "observee_certainty" => "uncertain",
            "observee_company_teammate_id" => nil
          }
        }
      }
    )
  end

  it "includes people from OGO-worthy cues only" do
    expect(described_class.call(consult: consult)).to contain_exactly(observer.id, observee.id)
  end
end
