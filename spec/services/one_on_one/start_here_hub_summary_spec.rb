# frozen_string_literal: true

require "rails_helper"

RSpec.describe OneOnOne::StartHereHubSummary do
  describe ".from_carousel_data" do
    it "picks the first applicable priority that needs attention as the top title" do
      data = {
        priorities: [
          { title: "First", needs_attention: false, not_applicable: false },
          { title: "Second needs you", needs_attention: true, not_applicable: false },
          { title: "Third", needs_attention: true, not_applicable: false }
        ]
      }
      summary = described_class.from_carousel_data(data)

      expect(summary[:top_title]).to eq("Second needs you")
      expect(summary[:total_count]).to eq(3)
      expect(summary[:green_count]).to eq(1)
      expect(summary[:needs_attention_count]).to eq(2)
    end

    it "when nothing needs attention, uses a healthy headline" do
      data = {
        priorities: [
          { title: "A", needs_attention: false, not_applicable: false }
        ]
      }
      summary = described_class.from_carousel_data(data)

      expect(summary[:top_title]).to eq("Nothing needs attention right now")
      expect(summary[:green_count]).to eq(1)
      expect(summary[:needs_attention_count]).to eq(0)
    end

    it "ignores not_applicable rows in counts" do
      data = {
        priorities: [
          { title: "N/A", needs_attention: false, not_applicable: true },
          { title: "OK", needs_attention: false, not_applicable: false }
        ]
      }
      summary = described_class.from_carousel_data(data)

      expect(summary[:total_count]).to eq(1)
      expect(summary[:green_count]).to eq(1)
    end
  end
end
