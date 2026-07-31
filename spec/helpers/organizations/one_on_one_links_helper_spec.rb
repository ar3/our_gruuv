# frozen_string_literal: true

require "rails_helper"

RSpec.describe Organizations::OneOnOneLinksHelper, type: :helper do
  describe "#engagement_health_last_event_display" do
    it "shows a secondary new-assignment badge during grace instead of red Never" do
      item = EngagementHealthStatus.new(
        status: EngagementHealth::WARNING,
        inputs: {
          "never" => true,
          "new_assignment_grace" => true,
          "days_since_tenure_chain_start" => 8,
          "new_assignment_grace_within_days" => 60
        }
      )

      html = helper.engagement_health_last_event_display(item)
      expect(html).to include("New — no check-in yet (day 8 of 60)")
      expect(html).to include("text-bg-secondary")
      expect(html).not_to include("text-bg-danger")
    end

    it "keeps red Never when never-finalized and not in grace" do
      item = EngagementHealthStatus.new(
        status: EngagementHealth::NEEDS_ATTENTION,
        inputs: { "never" => true, "new_assignment_grace" => false }
      )

      html = helper.engagement_health_last_event_display(item)
      expect(html).to include("Never")
      expect(html).to include("text-bg-danger")
    end
  end
end
