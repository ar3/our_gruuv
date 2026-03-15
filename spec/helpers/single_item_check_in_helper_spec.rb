# frozen_string_literal: true

require "rails_helper"

RSpec.describe SingleItemCheckInHelper do
  include described_class

  describe "#single_item_check_in_bucket_emoji" do
    it "returns ‼️ for red" do
      expect(single_item_check_in_bucket_emoji(:red)).to eq("‼️")
    end

    it "returns ⚠️ for yellow" do
      expect(single_item_check_in_bucket_emoji(:yellow)).to eq("⚠️")
    end

    it "returns ✅ for green" do
      expect(single_item_check_in_bucket_emoji(:green)).to eq("✅")
    end

    it "returns ‼️ for nil or unknown" do
      expect(single_item_check_in_bucket_emoji(nil)).to eq("‼️")
    end
  end
end
