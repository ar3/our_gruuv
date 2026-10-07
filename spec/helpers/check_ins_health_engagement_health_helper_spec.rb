# frozen_string_literal: true

require "rails_helper"

RSpec.describe CheckInsHealthEngagementHealthHelper, type: :helper do
  describe "#check_ins_health_engagement_last_check_in_phrase" do
    it "uses days_since_last_event" do
      item = EngagementHealthStatus.new(
        status: EngagementHealth::WARNING,
        inputs: { "days_since_last_event" => 70, "never" => false }
      )

      expect(helper.check_ins_health_engagement_last_check_in_phrase(item)).to eq(
        "Last check-in was 70 days ago"
      )
    end

    it "singularizes one day" do
      item = EngagementHealthStatus.new(
        status: EngagementHealth::WARNING,
        inputs: { "days_since_last_event" => 1, "never" => false }
      )

      expect(helper.check_ins_health_engagement_last_check_in_phrase(item)).to eq(
        "Last check-in was 1 day ago"
      )
    end

    it "says this will be the first check-in when never finalized" do
      item = EngagementHealthStatus.new(
        status: EngagementHealth::NEEDS_ATTENTION,
        inputs: { "never" => true }
      )

      expect(helper.check_ins_health_engagement_last_check_in_phrase(item)).to eq(
        "This will be the first check-in"
      )
    end
  end

  describe "#check_ins_health_engagement_alert_data" do
    let(:organization) { create(:organization, :company) }
    let(:teammate) { create(:company_teammate, organization: organization) }

    it "puts last-check-in age in the consider banner instead of status label" do
      record = EngagementHealthStatus.create!(
        teammate: teammate,
        organization: organization,
        level: "item",
        category: EngagementHealth::CATEGORY_REQUIRED_CLARITY,
        entity_type: "Assignment",
        entity_id: 1,
        status: EngagementHealth::WARNING,
        inputs: {
          "name" => "Finance",
          "days_since_last_event" => 75,
          "never" => false,
          "open_check_in_present" => false
        },
        computed_at: Time.current
      )

      data = helper.check_ins_health_engagement_alert_data(
        records: [record],
        organization: organization,
        teammate: teammate
      )

      expect(data[:all_clear]).to be(false)
      expect(data[:message]).to eq("Consider checking in on: Finance (Last check-in was 75 days ago)")
    end
  end
end
