# frozen_string_literal: true

require "rails_helper"

RSpec.describe PossibleObservationConsults::ApplyFirstPassResults do
  let(:organization) { create(:organization) }
  let(:natalie) { create(:person, full_name: "Natalie Morgan", preferred_name: "Natalie") }
  let!(:natalie_tm) { create(:company_teammate, person: natalie, organization: organization, first_employed_at: 1.year.ago) }
  let(:brett) { create(:person, full_name: "Brett Example", preferred_name: "Brett") }
  let!(:brett_tm) { create(:company_teammate, person: brett, organization: organization, first_employed_at: 1.year.ago) }
  let(:consult) do
    create(
      :possible_observation_consult,
      organization: organization,
      creator_company_teammate: natalie_tm,
      first_pass_status: "processing",
      source_text: <<~VTT
        WEBVTT

        1
        00:12:00.000 --> 00:12:05.000
        Natalie Morgan: I just want to shout out Brett for helping.
      VTT
    )
  end
  let(:cues) { Transcripts::ParseCuesService.call(raw: consult.source_raw) }

  it "prefers teammate ids from the combined first-pass call" do
    cue_id = cues.first.fetch("id")
    described_class.call(
      consult: consult,
      cues: cues,
      llm_by_cue_id: {
        cue_id => {
          "ogo_worthy" => true,
          "observer_label" => "Natalie Morgan",
          "observee_labels" => ["Brett"],
          "observer_company_teammate_id" => natalie_tm.id,
          "observee_company_teammate_ids" => [brett_tm.id],
          "reason" => "shout-out"
        }
      }
    )

    consult.reload
    expect(consult.first_pass_status).to eq("completed")
    expect(consult.speaker_map_labels["Natalie Morgan"][:company_teammate_id]).to eq(natalie_tm.id)
    row = consult.cue_annotation_rows[cue_id]
    expect(row[:ogo_worthy]).to eq(true)
    expect(row[:cue_status]).to eq("ogo_worthy")
    expect(row[:observee_company_teammate_id]).to eq(brett_tm.id)
    expect(row[:observee_company_teammate_ids]).to eq([brett_tm.id])
    expect(consult.moment_cues.map { |c| c[:id] }).to eq([cue_id])
  end

  it "falls back to deterministic name match when ids are blank (no LLM resolve)" do
    cue_id = cues.first.fetch("id")
    expect(Transcripts::TeammateResolverService).to receive(:call)
      .at_least(:once)
      .with(hash_including(allow_llm: false))
      .and_call_original

    described_class.call(
      consult: consult,
      cues: cues,
      llm_by_cue_id: {
        cue_id => {
          "ogo_worthy" => true,
          "observer_label" => "Natalie Morgan",
          "observee_labels" => ["Brett"],
          "observer_company_teammate_id" => nil,
          "observee_company_teammate_ids" => [],
          "reason" => "shout-out"
        }
      }
    )

    expect(consult.reload.cue_annotation_rows[cue_id][:observee_company_teammate_id]).to eq(brett_tm.id)
  end

  it "expands multi-moment first-pass splits into separate Step 2 rows" do
    amy = create(:person, full_name: "Amy Example", preferred_name: "Amy")
    amy_tm = create(:company_teammate, person: amy, organization: organization, first_employed_at: 1.year.ago)
    kayla = create(:person, full_name: "Kayla Example", preferred_name: "Kayla")
    kayla_tm = create(:company_teammate, person: kayla, organization: organization, first_employed_at: 1.year.ago)
    split_text =
      "First, for Kayla. I appreciate you. Couple more. Which is Amy. She cares so much."
    split_cues = [
      {
        "id" => "cue-1",
        "speaker_label" => "Natalie Morgan",
        "kind" => "speech",
        "text" => split_text,
        "start" => "00:12:00.000",
        "end" => "00:12:40.000"
      }
    ]

    described_class.call(
      consult: consult,
      cues: split_cues,
      llm_by_cue_id: {
        "cue-1" => {
          "moments" => [
            {
              "ogo_worthy" => true,
              "excerpt" => "First, for Kayla. I appreciate you. ",
              "observer_label" => "Natalie Morgan",
              "observee_labels" => ["Kayla"],
              "observer_company_teammate_id" => natalie_tm.id,
              "observee_company_teammate_ids" => [kayla_tm.id],
              "reason" => "shout-out Kayla"
            },
            {
              "ogo_worthy" => true,
              "excerpt" => "Couple more. Which is Amy. She cares so much.",
              "observer_label" => "Natalie Morgan",
              "observee_labels" => ["Amy"],
              "observer_company_teammate_id" => natalie_tm.id,
              "observee_company_teammate_ids" => [amy_tm.id],
              "reason" => "shout-out Amy"
            }
          ]
        }
      }
    )

    moments = consult.reload.moment_cues
    expect(moments.size).to eq(2)
    expect(moments.map { |m| m[:text].to_s }).to include(
      a_string_including("Kayla"),
      a_string_including("Amy")
    )
    expect(moments.map { |m| m[:text].to_s }).to all(satisfy { |text| split_text.include?(text) })
    rows = consult.cue_annotation_rows.values
    expect(rows.count { |row| row[:ogo_worthy] }).to eq(2)
    expect(rows.map { |row| row[:observee_company_teammate_id] }).to contain_exactly(kayla_tm.id, amy_tm.id)
  end

  it "replaces invented excerpts with the original cue text" do
    cue_id = cues.first.fetch("id")
    described_class.call(
      consult: consult,
      cues: cues,
      llm_by_cue_id: {
        cue_id => {
          "moments" => [
            {
              "ogo_worthy" => true,
              "excerpt" => "Completely invented unrelated feedback about someone else.",
              "observer_label" => "Natalie Morgan",
              "observee_labels" => ["Brett"],
              "observer_company_teammate_id" => natalie_tm.id,
              "observee_company_teammate_ids" => [brett_tm.id],
              "reason" => "bad excerpt"
            }
          ]
        }
      }
    )

    moment = consult.reload.moment_cues.first
    expect(moment[:text]).to eq(cues.first.fetch("text"))
  end
end
