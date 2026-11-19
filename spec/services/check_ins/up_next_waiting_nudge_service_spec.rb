# frozen_string_literal: true

require "rails_helper"

RSpec.describe CheckIns::UpNextWaitingNudgeService do
  let(:company) { create(:organization, :company, :with_slack_config) }
  let(:employee_teammate) { create(:teammate, :assigned_employee, organization: company) }
  let(:manager_teammate) { create(:teammate, :assigned_employee, organization: company) }
  let!(:employment_tenure) do
    create(
      :employment_tenure,
      teammate: employee_teammate,
      company: company,
      manager: manager_teammate,
      started_at: 1.year.ago
    )
  end

  before do
    create(:teammate_identity, :slack, teammate: employee_teammate, uid: "U111EMPLOYEE")
    create(:teammate_identity, :slack, teammate: manager_teammate, uid: "U222MANAGER")
  end

  describe ".message_body" do
    it "includes the tag-you're-it copy and count" do
      text = described_class.message_body(waiting_count: 2, up_next_url: "https://example.test/up-next")
      expect(text).to include("Tag you're it")
      expect(text).to include("the 2 check-ins")
      expect(text).to include("https://example.test/up-next")
    end
  end

  describe ".call" do
    it "posts a Slack MPIM and records the notification on the employee" do
      slack_service = instance_double(SlackService)
      allow(SlackService).to receive(:new).with(company).and_return(slack_service)
      allow(slack_service).to receive(:open_or_create_group_dm)
        .with(user_ids: %w[U222MANAGER U111EMPLOYEE])
        .and_return({ success: true, channel_id: "G01234567" })
      allow(slack_service).to receive(:post_message) do |notification_id|
        Notification.find(notification_id).update!(status: "sent_successfully", message_id: "1234.5678")
        { success: true, message_id: "1234.5678" }
      end

      result = described_class.call(
        organization: company,
        employee_teammate: employee_teammate,
        viewing_person: manager_teammate.person,
        viewing_teammate: manager_teammate,
        waiting_count: 3
      )

      expect(result.ok?).to be true
      n = result.value[:notification]
      expect(n.notification_type).to eq("check_in_up_next_waiting_nudge")
      expect(n.notifiable).to eq(employee_teammate)
      expect(n.metadata["pair_company_teammate_ids"]).to eq([employee_teammate.id, manager_teammate.id].sort)
      expect(n.fallback_text).to include("Tag you're it")
      expect(n.fallback_text).to include("the 3 check-ins")
    end

    it "errors when Slack is missing for a recipient" do
      employee_teammate.teammate_identities.slack.destroy_all

      result = described_class.call(
        organization: company,
        employee_teammate: employee_teammate,
        viewing_person: manager_teammate.person,
        viewing_teammate: manager_teammate,
        waiting_count: 1
      )

      expect(result.ok?).to be false
      expect(result.error).to include("Slack connected")
    end
  end
end
