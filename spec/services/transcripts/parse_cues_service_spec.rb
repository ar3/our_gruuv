# frozen_string_literal: true

require "rails_helper"

RSpec.describe Transcripts::ParseCuesService do
  let(:vtt) do
    <<~VTT
      WEBVTT

      1
      00:03:00.100 --> 00:03:01.420
      Natalie Morgan: Hi, AC.

      2
      00:03:29.680 --> 00:03:39.150
      Audio shared by Natalie Morgan: This is Halloween

      3
      00:05:43.000 --> 00:05:44.140
      polly (she/her): Yeah, I'm here.
    VTT
  end

  it "parses VTT cues with speakers and timing" do
    cues = described_class.call(raw: vtt)
    expect(cues.size).to eq(3)
    expect(cues[0]).to include(
      "speaker_label" => "Natalie Morgan",
      "text" => "Hi, AC.",
      "start" => "00:03:00.100",
      "kind" => "speech"
    )
    expect(cues[1]).to include(
      "speaker_label" => "Audio shared by Natalie Morgan",
      "kind" => "audio_share"
    )
    expect(cues[2]["speaker_label"]).to eq("polly (she/her)")
  end
end
