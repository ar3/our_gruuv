# frozen_string_literal: true

require "rails_helper"

RSpec.describe PossibleObservationConsultFirstPassJob, type: :job do
  let(:organization) { create(:organization) }
  let(:creator) { create(:company_teammate, organization: organization, first_employed_at: 1.year.ago) }
  let(:consult) do
    create(
      :possible_observation_consult,
      :first_pass_pending,
      organization: organization,
      creator_company_teammate: creator,
      source_text: <<~VTT
        WEBVTT

        1
        00:01:00.000 --> 00:01:02.000
        Pat Subject: Pat did a great job shipping the launch.
      VTT
    )
  end

  it "applies LLM first-pass results and marks the consult completed" do
    cues = Transcripts::MomentCuesService.call(raw: consult.source_raw)
    cue_id = cues.first.fetch("id")
    allow(Llm::TranscriptCueFirstPass).to receive(:call).and_return(
      cue_id => {
        "moments" => [
          {
            "ogo_worthy" => true,
            "observer_label" => "Pat Subject",
            "observee_labels" => ["Pat"],
            "excerpt" => "Pat did a great job shipping the launch.",
            "reason" => "praise"
          }
        ]
      }
    )

    described_class.perform_now(consult.id)

    consult.reload
    expect(consult.first_pass_status).to eq("completed")
    expect(consult.cue_annotation_rows[cue_id][:ogo_worthy]).to eq(true)
    expect(Llm::TranscriptCueFirstPass).to have_received(:call)
  end

  it "merges consecutive same-speaker caption blocks before the LLM pass" do
    consult.update!(
      source_text: <<~VTT
        WEBVTT

        1
        00:12:22.000 --> 00:12:28.000
        Pat Subject: I just want to shout out the team.

        2
        00:12:28.500 --> 00:12:35.000
        Pat Subject: They crushed the launch this week.
      VTT
    )

    allow(Llm::TranscriptCueFirstPass).to receive(:call) do |kwargs|
      expect(kwargs[:cues].size).to eq(1)
      expect(kwargs[:cues].first["merged"]).to eq(true)
      expect(kwargs[:cues].first["text"]).to include("shout out the team")
      expect(kwargs[:cues].first["text"]).to include("crushed the launch")
      {
        "cue-1" => {
          "moments" => [
            {
              "ogo_worthy" => true,
              "observer_label" => "Pat Subject",
              "observee_labels" => [],
              "excerpt" => "I just want to shout out the team. They crushed the launch this week.",
              "reason" => "praise"
            }
          ]
        }
      }
    end

    described_class.perform_now(consult.id)
    expect(consult.reload.first_pass_status).to eq("completed")
  end

  it "completes with empty maps when parse yields no cues" do
    allow(Transcripts::MomentCuesService).to receive(:call).and_return([])
    described_class.perform_now(consult.id)

    consult.reload
    expect(consult.first_pass_status).to eq("completed")
    expect(consult.speaker_map_labels).to eq({})
    expect(consult.cue_annotation_rows).to eq({})
  end

  it "marks failed when the LLM raises" do
    allow(Llm::TranscriptCueFirstPass).to receive(:call).and_raise(StandardError, "bedrock down")

    described_class.perform_now(consult.id)

    consult.reload
    expect(consult.first_pass_status).to eq("failed")
    expect(consult.first_pass_error).to include("bedrock down")
  end
end
