# frozen_string_literal: true

require "rails_helper"

RSpec.describe Transcripts::MergeCuesService do
  def atom(id:, speaker:, text:, start_ms:, end_ms:, kind: "speech", start: nil, end_label: nil)
    {
      "id" => id,
      "speaker_label" => speaker,
      "text" => text,
      "start_ms" => start_ms,
      "end_ms" => end_ms,
      "start" => start,
      "end" => end_label,
      "kind" => kind
    }
  end

  it "merges consecutive same-speaker blocks with a short gap into one moment" do
    cues = [
      atom(
        id: "cue-1", speaker: "Corbin Dodson", text: "I just want to shout out Brett.",
        start_ms: 742_000, end_ms: 748_000, start: "00:12:22.000", end_label: "00:12:28.000"
      ),
      atom(
        id: "cue-2", speaker: "Corbin Dodson", text: "He's been super helpful during training.",
        start_ms: 749_000, end_ms: 755_000, start: "00:12:29.000", end_label: "00:12:35.000"
      ),
      atom(
        id: "cue-3", speaker: "Natalie Morgan", text: "Thanks everyone.",
        start_ms: 760_000, end_ms: 762_000, start: "00:12:40.000", end_label: "00:12:42.000"
      )
    ]

    merged = described_class.call(cues: cues)
    expect(merged.size).to eq(2)
    expect(merged.first).to include(
      "id" => "cue-1",
      "speaker_label" => "Corbin Dodson",
      "merged" => true,
      "source_block_count" => 2,
      "text" => "I just want to shout out Brett. He's been super helpful during training."
    )
    expect(merged.first["source_cue_ids"]).to eq(%w[cue-1 cue-2])
    expect(merged.first["start"]).to eq("00:12:22.000")
    expect(merged.first["end"]).to eq("00:12:35.000")
    expect(merged.last["speaker_label"]).to eq("Natalie Morgan")
    expect(merged.last["merged"]).to eq(false)
  end

  it "does not merge different speakers or speech with audio-share" do
    cues = [
      atom(id: "cue-1", speaker: "A", text: "Hi", start_ms: 0, end_ms: 1_000),
      atom(id: "cue-2", speaker: "B", text: "Hello", start_ms: 1_100, end_ms: 2_000),
      atom(
        id: "cue-3", speaker: "Audio shared by A", text: "lyrics",
        start_ms: 2_100, end_ms: 3_000, kind: "audio_share"
      )
    ]

    merged = described_class.call(cues: cues)
    expect(merged.size).to eq(3)
    expect(merged.map { |c| c["merged"] }).to all(eq(false))
  end

  it "merges consecutive same-speaker audio-share blocks even across long gaps" do
    cues = [
      atom(
        id: "cue-1", speaker: "Audio shared by Natalie Morgan", text: "This is Halloween",
        start_ms: 10_000, end_ms: 12_000, kind: "audio_share",
        start: "00:00:10.000", end_label: "00:00:12.000"
      ),
      atom(
        id: "cue-2", speaker: "Audio shared by Natalie Morgan", text: "this is Halloween",
        start_ms: 12_200, end_ms: 14_000, kind: "audio_share",
        start: "00:00:12.200", end_label: "00:00:14.000"
      ),
      atom(
        id: "cue-3", speaker: "Audio shared by Natalie Morgan", text: "Halloween! Halloween!",
        start_ms: 90_000, end_ms: 92_000, kind: "audio_share",
        start: "00:01:30.000", end_label: "00:01:32.000"
      ),
      atom(
        id: "cue-4", speaker: "Natalie Morgan", text: "Okay back to the agenda.",
        start_ms: 95_000, end_ms: 97_000, kind: "speech"
      )
    ]

    merged = described_class.call(cues: cues)
    expect(merged.size).to eq(2)
    expect(merged.first).to include(
      "kind" => "audio_share",
      "merged" => true,
      "source_block_count" => 3
    )
    expect(merged.first["text"]).to include("Halloween! Halloween!")
    expect(merged.last["speaker_label"]).to eq("Natalie Morgan")
  end

  it "merges unfinished same-speaker captions across a slightly longer gap" do
    cues = [
      atom(id: "cue-1", speaker: "Pat", text: "I want to thank", start_ms: 0, end_ms: 1_000),
      atom(id: "cue-2", speaker: "Pat", text: "Alex for shipping this.", start_ms: 5_500, end_ms: 7_000)
    ]

    merged = described_class.call(cues: cues)
    expect(merged.size).to eq(1)
    expect(merged.first["merged"]).to eq(true)
  end
end
