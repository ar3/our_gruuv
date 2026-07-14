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

  describe "#single_item_object_queue_viewer_chip_label" do
    it "labels your turn strongly" do
      expect(single_item_object_queue_viewer_chip_label(:your_turn)).to eq("Your turn")
    end
  end

  describe "#single_item_object_queue_row_subcopy" do
    it "uses the counterpart name for waiting" do
      expect(
        single_item_object_queue_row_subcopy(
          { viewer_state: :waiting },
          employee_name: "Pat",
          manager_name: "Alex",
          manager_perspective: false
        )
      ).to eq("Waiting on Alex")
    end
  end

  describe "#single_item_object_queue_health_tooltip" do
    it "says never finalized when blank" do
      expect(single_item_object_queue_health_tooltip({ last_finalized_at: nil })).to eq("Never finalized")
    end

    it "uses time ago in words when present" do
      expect(single_item_object_queue_health_tooltip({ last_finalized_at: 3.days.ago })).to eq("Last finalized 3 days ago")
    end
  end
end
