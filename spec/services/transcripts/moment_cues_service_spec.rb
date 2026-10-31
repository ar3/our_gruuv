# frozen_string_literal: true

require "rails_helper"

RSpec.describe Transcripts::MomentCuesService do
  it "parses VTT then merges same-speaker moments" do
    raw = <<~VTT
      WEBVTT

      1
      00:12:22.000 --> 00:12:28.000
      Corbin Dodson: I just want to shout out Brett.

      2
      00:12:28.500 --> 00:12:35.000
      Corbin Dodson: He's been super helpful.
    VTT

    cues = described_class.call(raw: raw)
    expect(cues.size).to eq(1)
    expect(cues.first["merged"]).to eq(true)
    expect(cues.first["source_block_count"]).to eq(2)
    expect(cues.first["text"]).to include("shout out Brett")
    expect(cues.first["text"]).to include("super helpful")
  end

  it "splits a merged turn that pivots to a second shout-out" do
    raw = <<~VTT
      WEBVTT

      1
      00:12:00.000 --> 00:12:20.000
      Andrew: First, for, Kayla and Nicole. So, Kayla and Nicole, I appreciate you. Let's go.

      2
      00:12:20.500 --> 00:12:45.000
      Andrew: Couple more… Well, let me just go to the one, which is Amy. She cares so freaking much.
    VTT

    cues = described_class.call(raw: raw)
    expect(cues.size).to eq(2)
    expect(cues.first["text"]).to include("Kayla and Nicole")
    expect(cues.last["text"]).to include("Amy")
  end
end

