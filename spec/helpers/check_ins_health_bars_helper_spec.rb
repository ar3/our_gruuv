# frozen_string_literal: true

require "rails_helper"

RSpec.describe CheckInsHealthBarsHelper, type: :helper do
  describe "#check_ins_health_item_initials" do
    it "uses first letters of the first two words" do
      expect(helper.check_ins_health_item_initials("Customer Support")).to eq("CS")
    end

    it "uses the first two alphanumeric characters for a single word" do
      expect(helper.check_ins_health_item_initials("Finance")).to eq("FI")
    end

    it "returns ? for blank names" do
      expect(helper.check_ins_health_item_initials("")).to eq("?")
    end
  end

  describe "#check_ins_health_popover_person_name" do
    it "uses casual_name" do
      person = build(:person, first_name: "Jordan", last_name: "Lee", preferred_name: nil)
      expect(helper.send(:check_ins_health_popover_person_name, person, fallback: "Employee")).to eq("Jordan L.")
    end
  end

  describe "popover workflow names" do
    let(:organization) { create(:organization, :company) }

    it "disambiguates with last initial when casual names match" do
      employee_person = create(:person, first_name: "Casey", last_name: "Morgan", preferred_name: "Casey")
      manager_person = create(:person, first_name: "Casey", last_name: "Reed", preferred_name: "Casey")
      teammate = create(:company_teammate, person: employee_person, organization: organization)
      manager_teammate = create(:company_teammate, person: manager_person, organization: organization)
      create(:employment_tenure, teammate: teammate, company: organization, manager_teammate: manager_teammate)

      names = helper.send(:teammate_and_manager_short_names, teammate, organization)

      expect(names[:employee]).to eq("Casey M.")
      expect(names[:manager]).to eq("Casey R.")
    end

    it "adds role labels when names still match after disambiguation" do
      employee_person = create(:person, first_name: "Casey", last_name: "Morgan", preferred_name: "Casey")
      manager_person = create(:person, first_name: "Casey", last_name: "Morgan", preferred_name: "Casey")
      teammate = create(:company_teammate, person: employee_person, organization: organization)
      manager_teammate = create(:company_teammate, person: manager_person, organization: organization)
      create(:employment_tenure, teammate: teammate, company: organization, manager_teammate: manager_teammate)

      names = helper.send(:teammate_and_manager_short_names, teammate, organization)

      expect(names[:employee]).to eq("Casey M. (employee)")
      expect(names[:manager]).to eq("Casey M. (manager)")
    end
  end

  describe "#check_ins_health_resolved_action_bar_color" do
    it "infers a healthy label when workflow fields are missing from stale EH rows" do
      item = EngagementHealthStatus.new(
        status: EngagementHealth::HEALTHY,
        inputs: { "name" => "Finance", "last_event_at" => 10.days.ago.iso8601, "days_since_last_event" => 10 }
      )

      expect(helper.check_ins_health_resolved_action_bar_color(item)).to eq("neon_green_striped")
      expect(helper.send(:check_ins_health_bar_popover_html, item: item, employee_name: "Alex", manager_name: "Casey")).to include(
        "Healthy — previous check-in finalized and acknowledged"
      )
    end
  end

  describe "#check_ins_health_resolved_days_until_warning" do
    it "computes days from days_since_last_event when days_until_warning is missing" do
      item = EngagementHealthStatus.new(
        status: EngagementHealth::HEALTHY,
        inputs: { "days_since_last_event" => 50 }
      )

      expect(helper.check_ins_health_resolved_days_until_warning(item)).to eq(11)
    end

    it "computes days from last_event_at when both workflow day fields are missing" do
      item = EngagementHealthStatus.new(
        status: EngagementHealth::HEALTHY,
        inputs: { "last_event_at" => 20.days.ago.iso8601 }
      )

      expect(helper.check_ins_health_resolved_days_until_warning(item)).to eq(41)
    end
  end

  describe "healthy popover body" do
    it "includes the day count for healthy items" do
      item = EngagementHealthStatus.new(
        status: EngagementHealth::HEALTHY,
        inputs: { "days_since_last_event" => 50 }
      )

      body = helper.send(:healthy_popover_body, item: item)
      expect(body).to include("Consider a check-in in 11 days")
    end
  end

  describe "#check_ins_health_bar_segment_url" do
    let(:organization) { create(:organization, :company) }
    let(:teammate) { create(:company_teammate, organization: organization) }

    it "routes assignments to the teammate assignment page" do
      url = helper.check_ins_health_bar_segment_url(
        organization: organization,
        teammate: teammate,
        entity_type: "Assignment",
        entity_id: 42
      )

      expect(url).to eq(organization_teammate_assignment_path(organization, teammate, 42))
    end
  end
end
