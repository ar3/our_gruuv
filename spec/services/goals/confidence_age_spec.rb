# frozen_string_literal: true

require "rails_helper"

RSpec.describe Goals::ConfidenceAge do
  let(:as_of) { Date.new(2026, 11, 25) }

  def check_in_monday(days_ago)
    build(:goal_check_in, check_in_week_start: as_of - days_ago)
  end

  describe ".bucket" do
    it "returns :never with no check-in" do
      expect(described_class.bucket(nil, as_of: as_of)).to eq(:never)
    end

    it "returns :fresh within 7 days" do
      expect(described_class.bucket(check_in_monday(7), as_of: as_of)).to eq(:fresh)
    end

    it "returns :aging from 8 through 21 days" do
      expect(described_class.bucket(check_in_monday(8), as_of: as_of)).to eq(:aging)
      expect(described_class.bucket(check_in_monday(21), as_of: as_of)).to eq(:aging)
    end

    it "returns :stale after 21 days" do
      expect(described_class.bucket(check_in_monday(22), as_of: as_of)).to eq(:stale)
    end
  end

  describe ".stale?" do
    it "is true only for the stale bucket" do
      expect(described_class.stale?(check_in_monday(22), as_of: as_of)).to be true
      expect(described_class.stale?(check_in_monday(21), as_of: as_of)).to be false
    end
  end
end
