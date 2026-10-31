# frozen_string_literal: true

require "rails_helper"

RSpec.describe PossibleObservationConsults::CollapseIgnoredMoments do
  it "collapses consecutive ignore cues from the same speaker only" do
    cues = [
      { "id" => "cue-1", "speaker_label" => "Host", "text" => "Next slide", "kind" => "speech", "start" => "1", "end" => "2" },
      { "id" => "cue-2", "speaker_label" => "Host", "text" => "Thanks everyone", "kind" => "speech", "start" => "3", "end" => "4" },
      { "id" => "cue-3", "speaker_label" => "Pat", "text" => "Shout out to Alex", "kind" => "speech", "start" => "5", "end" => "6" },
      { "id" => "cue-4", "speaker_label" => "Host", "text" => "Moving on", "kind" => "speech", "start" => "7", "end" => "8" }
    ]
    annotations = {
      "cue-1" => { "ogo_worthy" => false, "cue_status" => "ignore", "first_pass_reason" => "logistics" },
      "cue-2" => { "ogo_worthy" => false, "cue_status" => "ignore", "first_pass_reason" => "logistics" },
      "cue-3" => { "ogo_worthy" => true, "cue_status" => "ogo_worthy", "first_pass_reason" => "praise" },
      "cue-4" => { "ogo_worthy" => false, "cue_status" => "ignore", "first_pass_reason" => "logistics" }
    }

    result = described_class.call(cues: cues, annotations: annotations)
    expect(result[:cues].size).to eq(3)
    expect(result[:cues][0]["text"]).to include("Next slide")
    expect(result[:cues][0]["text"]).to include("Thanks everyone")
    expect(result[:cues][0]["merged"]).to eq(true)
    expect(result[:annotations]["cue-1"][:ogo_worthy]).to eq(false)
    expect(result[:cues][1]["text"]).to eq("Shout out to Alex")
    expect(result[:annotations]["cue-2"][:ogo_worthy]).to eq(true)
    expect(result[:cues][2]["speaker_label"]).to eq("Host")
  end
end
