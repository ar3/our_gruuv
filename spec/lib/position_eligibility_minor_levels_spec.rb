# frozen_string_literal: true

require "rails_helper"

RSpec.describe PositionEligibilityMinorLevels do
  describe ".card_header_title" do
    it "returns Positions *.n for minors 1–3" do
      expect(described_class.card_header_title(1)).to eq("Positions *.1")
      expect(described_class.card_header_title(3)).to eq("Positions *.3")
    end

    it "rejects invalid minors" do
      expect { described_class.card_header_title(0) }.to raise_error(ArgumentError)
      expect { described_class.card_header_title(4) }.to raise_error(ArgumentError)
    end
  end

  describe ".header_caption_within_title" do
    it "appends within the title to each tier description" do
      expect(described_class.header_caption_within_title(2)).to eq("Established / solid experience within the title")
    end
  end

  describe ".TIER_DESCRIPTION" do
    it "defines all three minors" do
      expect(described_class::TIER_DESCRIPTION.keys).to contain_exactly(1, 2, 3)
    end
  end
end
