# frozen_string_literal: true

require "rails_helper"

RSpec.describe Transcripts::SplitDistinctShoutOutsService do
  let(:kayla_amy_text) do
    "Alright, a few. First, for, Kayla and Nicole. been meeting with them, we try once a week, but schedules, you know. " \
      "And what I've learned from them over these past couple months is a different take on collaboration. " \
      "So, Kayla and Nicole, I appreciate you. Let's go. Couple more… Well, let me just go to the one, which is Amy. " \
      "Y'all, I work with Amy pretty closely, these days, and the thing that I wanted to shout out Amy for… " \
      "Outside of just work anniversary, right, is the fact that she cares so freaking much about each and every one of you. Appreciator."
  end

  it "splits Kayla/Nicole then Amy into two verbatim moments" do
    cues = [
      {
        "id" => "cue-1",
        "speaker_label" => "Andrew",
        "kind" => "speech",
        "text" => kayla_amy_text,
        "source_block_count" => 14,
        "merged" => true
      }
    ]

    split = described_class.call(cues: cues)
    expect(split.size).to eq(2)
    expect(split.first["text"]).to include("Kayla and Nicole")
    expect(split.first["text"]).not_to include("which is Amy")
    expect(split.last["text"]).to include("Amy")
    expect(split.last["text"]).to include("Appreciator")
    expect(kayla_amy_text).to include(split.first["text"])
    expect(kayla_amy_text).to include(split.last["text"])
  end

  it "does not split audio-share cues" do
    cues = [
      {
        "id" => "cue-1",
        "speaker_label" => "Audio shared by Natalie",
        "kind" => "audio_share",
        "text" => "lyrics lyrics Couple more lyrics which is Amy lyrics"
      }
    ]

    expect(described_class.call(cues: cues).size).to eq(1)
  end
end
