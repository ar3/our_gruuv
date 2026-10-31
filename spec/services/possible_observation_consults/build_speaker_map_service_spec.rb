# frozen_string_literal: true

require "rails_helper"

RSpec.describe PossibleObservationConsults::BuildSpeakerMapService do
  let(:organization) { create(:organization) }
  let(:natalie) { create(:person, full_name: "Natalie Morgan", preferred_name: "Natalie") }
  let!(:natalie_tm) { create(:company_teammate, person: natalie, organization: organization, first_employed_at: 1.year.ago) }
  let(:consult) do
    create(
      :possible_observation_consult,
      :prompt_debug,
      organization: organization,
      creator_company_teammate: natalie_tm,
      source_text: <<~VTT
        WEBVTT

        1
        00:01:00.000 --> 00:01:01.000
        Natalie Morgan: Hello team.

        2
        00:01:02.000 --> 00:01:03.000
        Audio shared by Natalie Morgan: Halloween song lyrics.
      VTT
    )
  end

  it "resolves people and marks audio-share cues as ignore" do
    described_class.call(consult: consult)
    labels = consult.reload.speaker_map_labels
    cues = consult.cue_annotation_rows

    expect(labels["Natalie Morgan"][:certainty]).to eq("certain")
    expect(labels["Natalie Morgan"][:company_teammate_id]).to eq(natalie_tm.id)
    expect(labels["Audio shared by Natalie Morgan"][:kind]).to eq("audio_share")
    expect(labels["Audio shared by Natalie Morgan"][:company_teammate_id]).to be_nil
    expect(cues.values.count { |row| row[:cue_status] == "ignore" }).to be >= 1
    expect(cues.values.count { |row| row[:cue_status] == "ogo_worthy" }).to be >= 1
  end
end

