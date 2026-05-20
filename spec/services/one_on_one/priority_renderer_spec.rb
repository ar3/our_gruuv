# frozen_string_literal: true

require "rails_helper"

RSpec.describe OneOnOne::PriorityRenderer do
  let(:organization) { create(:organization) }
  let(:person) { create(:person, first_name: "Alex", last_name: "Smith") }
  let(:teammate) { create(:company_teammate, person: person, organization: organization) }

  describe "#action_item_slack_lines" do
    it "uses absolute URLs for structured item links (not path-only)" do
      assignment = create(:assignment, company: organization.root_company || organization, title: "Ship feature")
      allow(SlackAbsoluteUrls).to receive(:slack_url_options).and_return(host: "ourgruuv.test", protocol: "https")

      priority = {
        needs_attention: true,
        data_kind: :wtm_gap_without_goals_attention,
        items: [{ associable: assignment }],
        remaining_count: 0
      }

      renderer = described_class.new(priority: priority, organization: organization, teammate: teammate)
      lines = renderer.action_item_slack_lines

      expect(lines.join).to match(%r{<https://ourgruuv\.test/[^|]+\|Assignment: Ship feature>})
      expect(lines.join).not_to match(%r{<\s*/organizations})
    end
  end
end
