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

  describe "#primary_action for bulk_goals" do
    let(:priority) do
      {
        needs_attention: true,
        not_applicable: false,
        cta_kind: :bulk_goals,
        cta_label: "Create goals"
      }
    end

    it "links to the chooser when the viewer can create goals for the hub teammate" do
      renderer = described_class.new(
        priority: priority,
        organization: organization,
        teammate: teammate,
        viewer: teammate
      )

      action = renderer.primary_action
      expect(action[:disabled]).to eq(false)
      expect(action[:path]).to include("select_create")
      expect(action[:path]).to include("for_company_teammate_id=#{teammate.id}")
    end

    it "disables Create goals when the viewer cannot create for the hub teammate" do
      peer_person = create(:person, first_name: "Pat", last_name: "Peer")
      peer = create(:company_teammate, person: peer_person, organization: organization)

      renderer = described_class.new(
        priority: priority,
        organization: organization,
        teammate: teammate,
        viewer: peer
      )

      action = renderer.primary_action
      expect(action[:disabled]).to eq(true)
      expect(action[:path]).to be_nil
      expect(action[:disabled_reason]).to include("can't create goals for Alex")
      expect(action[:disabled_reason]).to include("managerial hierarchy")
    end
  end
end
