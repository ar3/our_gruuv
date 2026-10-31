# frozen_string_literal: true

require "rails_helper"

RSpec.describe Transcripts::NormalizeSpeakerLabel do
  it "strips Zoom pronoun suffixes" do
    expect(described_class.call("polly (she/her)")).to include(
      "normalized" => "polly",
      "kind" => "speech"
    )
    expect(described_class.call("Andrew Robinson III (he/him)")).to include(
      "normalized" => "Andrew Robinson III",
      "kind" => "speech"
    )
  end

  it "flags Audio shared by labels" do
    expect(described_class.call("Audio shared by Natalie Morgan")).to include(
      "normalized" => "Natalie Morgan",
      "kind" => "audio_share",
      "raw" => "Audio shared by Natalie Morgan"
    )
  end
end
