# frozen_string_literal: true

require "rails_helper"

RSpec.describe PossibleObservationSlackSearches::MessagePrefilter do
  def msg(text)
    { "text" => text, "ts" => "1.0", "channel_id" => "C1" }
  end

  it "keeps messages at or above the minimum stripped length" do
    short = msg("ok")
    borderline = msg("a" * PossibleObservationSlackSearches::MessagePrefilter::MIN_TEXT_CHARS)
    long = msg("This is a long enough Slack message about shipping the launch.")

    result = described_class.call([short, borderline, long])

    expect(result).to eq([borderline, long])
  end

  it "collapses whitespace before measuring length" do
    padded = msg("   #{'x' * 39}   ")
    expect(described_class.call([padded])).to eq([])
  end
end
