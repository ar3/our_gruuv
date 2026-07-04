# frozen_string_literal: true

require "rails_helper"

RSpec.describe EngagementHealth::WorkflowSnapshot do
  def call(status:, open_check_in: nil, last_closed_check_in: nil, days_since_last_event: nil)
    described_class.call(
      status: status,
      open_check_in: open_check_in,
      last_closed_check_in: last_closed_check_in,
      reference_time: Time.current,
      days_since_last_event: days_since_last_event
    )
  end

  def build_check_in(employee_at: nil, manager_at: nil, finalized_at: nil, acknowledged: false)
    check_in = instance_double(
      "CheckIn",
      id: 1,
      employee_completed_at: employee_at,
      manager_completed_at: manager_at,
      official_check_in_completed_at: finalized_at,
      created_at: 1.week.ago
    )
    ack_at = acknowledged ? 1.day.ago : nil
    snapshot = instance_double("MaapSnapshot", employee_acknowledged_at: ack_at)
    allow(check_in).to receive(:maap_snapshot).and_return(snapshot)
    check_in
  end

  describe "action_bar_color resolution" do
    it "returns light_green when both sides completed on open check-in" do
      open_ci = build_check_in(employee_at: 1.day.ago, manager_at: 1.day.ago)
      result = call(status: EngagementHealth::AT_RISK, open_check_in: open_ci)
      expect(result["action_bar_color"]).to eq("light_green")
    end

    it "returns light_blue when only employee completed" do
      open_ci = build_check_in(employee_at: 1.day.ago)
      result = call(status: EngagementHealth::HEALTHY, open_check_in: open_ci, days_since_last_event: 10)
      expect(result["action_bar_color"]).to eq("light_blue")
    end

    it "returns light_purple when only manager completed" do
      open_ci = build_check_in(manager_at: 1.day.ago)
      result = call(status: EngagementHealth::HEALTHY, open_check_in: open_ci, days_since_last_event: 10)
      expect(result["action_bar_color"]).to eq("light_purple")
    end

    it "returns red when needs attention with open check-in and neither side complete" do
      open_ci = build_check_in
      result = call(status: EngagementHealth::NEEDS_ATTENTION, open_check_in: open_ci)
      expect(result["action_bar_color"]).to eq("red")
    end

    it "returns orange when at risk with open check-in and neither side complete" do
      open_ci = build_check_in
      result = call(status: EngagementHealth::AT_RISK, open_check_in: open_ci)
      expect(result["action_bar_color"]).to eq("orange")
    end

    it "returns green_striped when healthy, open, neither complete, previous awaiting ack" do
      open_ci = build_check_in
      closed_ci = build_check_in(finalized_at: 20.days.ago, acknowledged: false)
      result = call(
        status: EngagementHealth::HEALTHY,
        open_check_in: open_ci,
        last_closed_check_in: closed_ci,
        days_since_last_event: 20
      )
      expect(result["action_bar_color"]).to eq("green_striped")
    end

    it "returns neon_green_striped when healthy, open, neither complete, previous acknowledged" do
      open_ci = build_check_in
      closed_ci = build_check_in(finalized_at: 20.days.ago, acknowledged: true)
      result = call(
        status: EngagementHealth::HEALTHY,
        open_check_in: open_ci,
        last_closed_check_in: closed_ci,
        days_since_last_event: 20
      )
      expect(result["action_bar_color"]).to eq("neon_green_striped")
    end

    it "returns red when needs attention and no open check-in" do
      result = call(status: EngagementHealth::NEEDS_ATTENTION)
      expect(result["action_bar_color"]).to eq("red")
    end

    it "returns orange when at risk and no open check-in" do
      result = call(status: EngagementHealth::AT_RISK)
      expect(result["action_bar_color"]).to eq("orange")
    end

    it "returns neon_green_striped when healthy, no open, previous acknowledged" do
      closed_ci = build_check_in(finalized_at: 20.days.ago, acknowledged: true)
      result = call(
        status: EngagementHealth::HEALTHY,
        last_closed_check_in: closed_ci,
        days_since_last_event: 20
      )
      expect(result["action_bar_color"]).to eq("neon_green_striped")
    end

    it "returns anomaly_gray for healthy open neither complete without prior finalized" do
      open_ci = build_check_in
      result = call(
        status: EngagementHealth::HEALTHY,
        open_check_in: open_ci,
        days_since_last_event: 10
      )
      expect(result["action_bar_color"]).to eq("anomaly_gray")
    end
  end

  describe "days_until_at_risk" do
    it "returns remaining days until at-risk while healthy" do
      closed_ci = build_check_in(finalized_at: 50.days.ago, acknowledged: true)
      result = call(
        status: EngagementHealth::HEALTHY,
        last_closed_check_in: closed_ci,
        days_since_last_event: 50
      )
      expect(result["days_until_at_risk"]).to eq(11)
    end

    it "returns zero when already at risk" do
      result = call(status: EngagementHealth::AT_RISK, days_since_last_event: 70)
      expect(result["days_until_at_risk"]).to eq(0)
    end
  end
end
