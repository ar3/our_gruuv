# frozen_string_literal: true

require "rails_helper"

RSpec.describe PossibleObservationConsults::MatchCuesToItems do
  it "links items to overlapping cues" do
    cues = [
      { "id" => "cue-1", "text" => "Brett has answered any and every question" },
      { "id" => "cue-2", "text" => "Unrelated filler line about lunch" }
    ]
    items = [
      {
        "id" => "item-1",
        "full_quote" => "Brett has answered any and every question, no matter how many times I interrupted him"
      }
    ]

    links = described_class.call(cues: cues, items: items)
    expect(links["item-1"]).to eq(["cue-1"])
  end
end
