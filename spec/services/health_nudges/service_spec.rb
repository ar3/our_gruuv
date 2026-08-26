# frozen_string_literal: true

require "rails_helper"

RSpec.describe HealthNudges::Service do
  let(:company) { create(:organization, :company, :with_slack_config) }
  let(:manager_teammate) { create(:teammate, :assigned_employee, organization: company) }
  let(:skip_teammate) { create(:teammate, :assigned_employee, organization: company) }
  let(:nudger_teammate) { create(:teammate, :assigned_employee, organization: company) }
  let(:stats) do
    {
      total_employees: 2,
      healthy_count: 1,
      warning_count: 0,
      needs_attention_count: 1
    }
  end

  before do
    create(:employment_tenure, teammate: manager_teammate, company: company, manager_teammate: skip_teammate, started_at: 1.year.ago)
    create(:teammate_identity, :slack, teammate: manager_teammate, uid: "U_MANAGER")
    create(:teammate_identity, :slack, teammate: skip_teammate, uid: "U_SKIP")
    create(:teammate_identity, :slack, teammate: nudger_teammate, uid: "U_NUDGER")
  end

  describe ".call" do
    it "posts one Slack thread reply per employee entry" do
      employee = create(:teammate, :assigned_employee, organization: company)
      slack_service = instance_double(SlackService)
      allow(SlackService).to receive(:new).with(company).and_return(slack_service)
      allow(slack_service).to receive(:open_or_create_group_dm)
        .and_return({ success: true, channel_id: "G_THREADS" })
      posted_ids = []
      allow(slack_service).to receive(:post_message) do |notification_id|
        posted_ids << notification_id
        Notification.find(notification_id).update!(status: "sent_successfully", message_id: "#{notification_id}.0")
        { success: true, message_id: "#{notification_id}.0" }
      end

      entries = HealthNudges::EmployeeEntries.from_goals_rows(
        [
          {
            teammate: employee,
            person: employee.person,
            status: :concerning,
            eh_status: EngagementHealth::NEEDS_ATTENTION,
            status_lines: {
              EngagementHealth::NEEDS_ATTENTION => { active: 1, completed: 0, draft: 0 }
            }
          }
        ]
      )

      result = described_class.call(
        organization: company,
        health_object: "goals_health",
        manager_teammate: manager_teammate,
        nudger_company_teammate: nudger_teammate,
        spotlight_stats: stats,
        recipient_scope: "manager",
        employee_entries: entries
      )

      expect(result.ok?).to be true
      expect(posted_ids.size).to eq(2)
      main = Notification.find(posted_ids.first)
      thread = Notification.find(posted_ids.last)
      expect(main.main_thread_id).to be_nil
      expect(thread.main_thread).to eq(main)
      expect(thread.fallback_text).to include(employee.person.casual_name)
      expect(thread.rich_message.first["type"] || thread.rich_message.first[:type]).to eq("section")
    end

    it "creates a health_nudge notification for check-ins health" do
      slack_service = instance_double(SlackService)
      allow(SlackService).to receive(:new).with(company).and_return(slack_service)
      allow(slack_service).to receive(:open_or_create_group_dm)
        .and_return({ success: true, channel_id: "G_CHECKINS" })
      allow(slack_service).to receive(:post_message) do |notification_id|
        Notification.find(notification_id).update!(status: "sent_successfully", message_id: "111.222")
        { success: true, message_id: "111.222" }
      end

      result = described_class.call(
        organization: company,
        health_object: "check_ins_health",
        manager_teammate: manager_teammate,
        nudger_company_teammate: nudger_teammate,
        spotlight_stats: stats,
        recipient_scope: "manager_and_skip"
      )

      expect(result.ok?).to be true
      n = result.value[:notification]
      expect(n.notification_type).to eq("health_nudge")
      expect(n.metadata["health_object"]).to eq("check_ins_health")
    end

    it "returns last delivered scoped to health object" do
      manager_teammate.notifications.create!(
        notification_type: "health_nudge",
        status: "sent_successfully",
        message_id: "1.1",
        metadata: { "health_object" => "milestones_health" }
      )
      goals_nudge = manager_teammate.notifications.create!(
        notification_type: "health_nudge",
        status: "sent_successfully",
        message_id: "2.2",
        metadata: { "health_object" => "goals_health" }
      )

      expect(described_class.last_delivered_for(manager_teammate: manager_teammate, health_object: "goals_health")).to eq(goals_nudge)
    end
  end
end
