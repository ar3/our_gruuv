# frozen_string_literal: true

require "rails_helper"

RSpec.describe Goals::HealthNudgeService do
  let(:company) { create(:organization, :company, :with_slack_config) }
  let(:manager_teammate) { create(:teammate, :assigned_employee, organization: company) }
  let(:skip_teammate) { create(:teammate, :assigned_employee, organization: company) }
  let(:nudger_teammate) { create(:teammate, :assigned_employee, organization: company) }
  let(:stats) do
    {
      total_employees: 2,
      healthy_count: 1,
      warning_count: 0,
      needs_attention_count: 1,
      ok_count: 0,
      concerning_count: 1
    }
  end

  before do
    create(:employment_tenure, teammate: manager_teammate, company: company, manager_teammate: skip_teammate, started_at: 1.year.ago)
    create(:teammate_identity, :slack, teammate: manager_teammate, uid: "U_MANAGER")
    create(:teammate_identity, :slack, teammate: skip_teammate, uid: "U_SKIP")
    create(:teammate_identity, :slack, teammate: nudger_teammate, uid: "U_NUDGER")
  end

  describe ".call" do
    it "sends manager_and_skip to viewer, manager, and skip-level" do
      slack_service = instance_double(SlackService)
      allow(SlackService).to receive(:new).with(company).and_return(slack_service)
      allow(slack_service).to receive(:open_or_create_group_dm) do |user_ids:|
        expect(user_ids).to match_array(%w[U_MANAGER U_SKIP U_NUDGER])
        { success: true, channel_id: "G_GOALS_NUDGE" }
      end
      allow(slack_service).to receive(:post_message) do |notification_id|
        Notification.find(notification_id).update!(status: "sent_successfully", message_id: "111.222")
        { success: true, message_id: "111.222" }
      end

      result = described_class.call(
        organization: company,
        manager_teammate: manager_teammate,
        nudger_company_teammate: nudger_teammate,
        spotlight_stats: stats,
        recipient_scope: "manager_and_skip"
      )

      expect(result.ok?).to be true
      n = result.value[:notification]
      expect(n.notification_type).to eq("goals_health_nudge")
      expect(n.notifiable).to eq(manager_teammate)
      expect(n.metadata["channel"]).to eq("G_GOALS_NUDGE")
      expect(n.metadata["health_object"]).to eq("goals_health")
      expect(n.metadata["recipient_scope"]).to eq("manager_and_skip")
      expect(n.metadata["nudger_company_teammate_id"]).to eq(nudger_teammate.id)
      expect(n.metadata["recipient_company_teammate_ids"]).to match_array(
        [ nudger_teammate.id, manager_teammate.id, skip_teammate.id ]
      )
      expect(n.message_id).to eq("111.222")
      expect(n.fallback_text).to include("Goals Health")
    end

    it "sends manager scope to viewer and manager only" do
      slack_service = instance_double(SlackService)
      allow(SlackService).to receive(:new).with(company).and_return(slack_service)
      allow(slack_service).to receive(:open_or_create_group_dm) do |user_ids:|
        expect(user_ids).to match_array(%w[U_MANAGER U_NUDGER])
        { success: true, channel_id: "G_MGR_ONLY" }
      end
      allow(slack_service).to receive(:post_message) do |notification_id|
        Notification.find(notification_id).update!(status: "sent_successfully", message_id: "333.444")
        { success: true, message_id: "333.444" }
      end

      result = described_class.call(
        organization: company,
        manager_teammate: manager_teammate,
        nudger_company_teammate: nudger_teammate,
        spotlight_stats: stats,
        recipient_scope: "manager"
      )

      expect(result.ok?).to be true
      n = result.value[:notification]
      expect(n.metadata["recipient_scope"]).to eq("manager")
      expect(n.metadata["recipient_company_teammate_ids"]).to match_array(
        [ nudger_teammate.id, manager_teammate.id ]
      )
    end

    it "returns an error when a recipient lacks Slack" do
      manager_teammate.teammate_identities.slack.destroy_all

      result = described_class.call(
        organization: company,
        manager_teammate: manager_teammate,
        nudger_company_teammate: nudger_teammate,
        spotlight_stats: stats,
        recipient_scope: "manager"
      )

      expect(result.ok?).to be false
      expect(result.error).to include("Slack")
    end

    it "returns an error for manager_and_skip when there is no skip-level manager" do
      manager_teammate.employment_tenures.update_all(manager_teammate_id: nil)

      result = described_class.call(
        organization: company,
        manager_teammate: manager_teammate,
        nudger_company_teammate: nudger_teammate,
        spotlight_stats: stats,
        recipient_scope: "manager_and_skip"
      )

      expect(result.ok?).to be false
      expect(result.error).to include("no manager on file")
    end
  end

  describe ".last_delivered_for" do
    it "returns the most recent successful goals health nudge for the manager" do
      older = manager_teammate.notifications.create!(
        notification_type: "goals_health_nudge",
        status: "sent_successfully",
        message_id: "1.1",
        metadata: { "health_object" => "goals_health" },
        created_at: 2.days.ago
      )
      newer = manager_teammate.notifications.create!(
        notification_type: "goals_health_nudge",
        status: "sent_successfully",
        message_id: "2.2",
        metadata: { "health_object" => "goals_health" },
        created_at: 1.hour.ago
      )
      manager_teammate.notifications.create!(
        notification_type: "check_in_acknowledgement_nudge",
        status: "sent_successfully",
        message_id: "3.3",
        created_at: Time.current
      )

      expect(described_class.last_delivered_for(manager_teammate: manager_teammate)).to eq(newer)
      expect(described_class.last_delivered_for(manager_teammate: manager_teammate)).not_to eq(older)
    end
  end
end
