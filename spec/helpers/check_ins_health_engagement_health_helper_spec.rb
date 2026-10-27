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

  describe "#check_ins_health_next_due_caption" do
    it "uses Next due when the end-of-warning date is still upcoming" do
      last = Date.current - 10.days
      due = last + EngagementHealth::Thresholds::REQUIRED_CLARITY_NEEDS_ATTENTION_AT_DAYS
      item = EngagementHealthStatus.new(
        status: EngagementHealth::HEALTHY,
        inputs: { "last_event_at" => last.iso8601, "never" => false }
      )

      expect(helper.check_ins_health_next_due_caption(item)).to eq(
        "Next due on #{due.strftime('%Y-%m-%d')}"
      )
    end

    it "uses Overdue as of when the end-of-warning date is past" do
      last = Date.current - 100.days
      due = last + EngagementHealth::Thresholds::REQUIRED_CLARITY_NEEDS_ATTENTION_AT_DAYS
      item = EngagementHealthStatus.new(
        status: EngagementHealth::NEEDS_ATTENTION,
        inputs: { "last_event_at" => last.iso8601, "never" => false }
      )

      expect(helper.check_ins_health_next_due_caption(item)).to eq(
        "Overdue as of #{due.strftime('%Y-%m-%d')}"
      )
    end

    it "describes never-finalized items without a due date" do
      item = EngagementHealthStatus.new(
        status: EngagementHealth::NEEDS_ATTENTION,
        inputs: { "never" => true, "name" => "Seat" }
      )

      expect(helper.check_ins_health_next_due_caption(item)).to eq("Overdue — first due")
    end

    it "uses Next due during Grey Grace when grace pushes due into the future" do
      grace_until = Date.current + 14.days
      item = EngagementHealthStatus.new(
        status: EngagementHealth::WARNING,
        inputs: {
          "never" => false,
          "last_event_at" => 100.days.ago.iso8601,
          "needs_attention_at" => (Date.current - 10.days).iso8601,
          "grace_until_at" => grace_until.iso8601,
          "clarity_check_in_grace" => true
        }
      )

      expect(helper.check_ins_health_next_due_caption(item)).to eq(
        "Next due on #{(grace_until + 1.day).strftime('%Y-%m-%d')}"
      )
    end
  end

  describe "#check_ins_health_action_summary_text_class" do
    it "uses grey text for Grey Grace items" do
      item = EngagementHealthStatus.new(
        status: EngagementHealth::WARNING,
        inputs: { "clarity_check_in_grace" => true }
      )

      expect(helper.check_ins_health_action_summary_text_class(item)).to eq("text-secondary")
    end

    it "still maps EH statuses when given a status string" do
      expect(helper.check_ins_health_action_summary_text_class(EngagementHealth::NEEDS_ATTENTION)).to eq("text-danger")
    end
  end


  describe "#check_ins_health_item_object_label" do
    it "prefixes the entity type when useful" do
      item = EngagementHealthStatus.new(
        entity_type: "Assignment",
        inputs: { "name" => "Finance" }
      )

      expect(helper.check_ins_health_item_object_label(item)).to eq("Assignment · Finance")
    end
  end
end
