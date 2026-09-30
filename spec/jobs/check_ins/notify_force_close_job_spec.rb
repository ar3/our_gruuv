# frozen_string_literal: true

require "rails_helper"

RSpec.describe CheckIns::NotifyForceCloseJob, type: :job do
  let(:organization) { create(:organization, :company) }
  let(:employee) { create(:person) }
  let(:manager) { create(:person) }
  let(:closer) { create(:person) }
  let(:employee_teammate) { create(:teammate, person: employee, organization: organization) }
  let(:manager_teammate) { CompanyTeammate.create!(person: manager, organization: organization) }
  let(:closer_teammate) { CompanyTeammate.create!(person: closer, organization: organization) }
  let(:assignment) { create(:assignment, company: organization, title: "Key Outcome Alpha") }
  let(:check_in) do
    create(
      :assignment_check_in,
      teammate: employee_teammate,
      assignment: assignment,
      official_check_in_completed_at: Time.current
    )
  end
  let(:slack_service) { instance_double(SlackService) }

  before do
    create(:employment_tenure,
      teammate: employee_teammate,
      company: organization,
      manager_teammate: manager_teammate,
      started_at: 1.month.ago,
      ended_at: nil)
    create(:teammate_identity, :slack, teammate: employee_teammate, uid: "U123456")
    create(:teammate_identity, :slack, teammate: manager_teammate, uid: "U789012")
    allow(SlackService).to receive(:new).and_return(slack_service)
  end

  it "posts a group DM to employee and manager with All check-ins link" do
    expect(slack_service).to receive(:open_or_create_group_dm).with(
      user_ids: ["U123456", "U789012"]
    ).and_return({ success: true, channel_id: "D123456" })

    expect(slack_service).to receive(:post_group_dm).with(
      channel_id: "D123456",
      text: include(closer.casual_name)
        .and(include("Key Outcome Alpha"))
        .and(include("force closed"))
        .and(include("No data was lost"))
        .and(include("All check-ins"))
        .and(include("research-all-check-ins"))
    ).and_return({ success: true, message_id: "123456.789" })

    expect {
      described_class.perform_now(
        check_in_id: check_in.id,
        organization_id: organization.id,
        closed_by_teammate_id: closer_teammate.id
      )
    }.to change(Notification, :count).by(1)

    notification = Notification.last
    expect(notification.notification_type).to eq("check_in_force_close")
    expect(notification.status).to eq("sent_successfully")
    expect(notification.notifiable).to eq(check_in)
  end

  it "skips when manager is missing" do
    EmploymentTenure.find_by!(company_teammate: employee_teammate, company: organization).update!(manager_teammate: nil)
    expect(slack_service).not_to receive(:open_or_create_group_dm)

    expect {
      described_class.perform_now(
        check_in_id: check_in.id,
        organization_id: organization.id,
        closed_by_teammate_id: closer_teammate.id
      )
    }.not_to change(Notification, :count)
  end
end
