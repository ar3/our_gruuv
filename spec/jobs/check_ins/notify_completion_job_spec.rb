require 'rails_helper'

RSpec.describe CheckIns::NotifyCompletionJob, type: :job do
  let(:organization) { create(:organization, :company) }
  let(:employee) { create(:person) }
  let(:manager) { create(:person) }
  let(:employee_teammate) { create(:teammate, person: employee, organization: organization) }
  let(:manager_teammate) { CompanyTeammate.create!(person: manager, organization: organization) }
  let(:slack_service) { instance_double(SlackService) }

  before do
    # Set up Slack identities
    create(:teammate_identity, :slack, teammate: employee_teammate, uid: 'U123456')
    create(:teammate_identity, :slack, teammate: manager_teammate, uid: 'U789012')
    
    allow(SlackService).to receive(:new).and_return(slack_service)
  end

  describe 'AssignmentCheckIn' do
    before do
      # Set up manager relationship for AssignmentCheckIn specs - ensure it's active
      create(:employment_tenure, 
        teammate: employee_teammate, 
        company: organization, 
        manager_teammate: manager_teammate, 
        started_at: 1.month.ago, 
        ended_at: nil)
    end
    let(:assignment) { create(:assignment, company: organization) }
    let(:check_in) { create(:assignment_check_in, teammate: employee_teammate, assignment: assignment) }

    context 'when employee completes (one side done)' do
      before do
        check_in.update!(employee_completed_at: Time.current)
      end

      it 'sends group DM to both employee and manager' do
        expect(slack_service).to receive(:open_or_create_group_dm).with(
          user_ids: ['U123456', 'U789012']
        ).and_return({ success: true, channel_id: 'D123456' })

        expect(slack_service).to receive(:post_group_dm).with(
          channel_id: 'D123456',
          text: include("#{employee.display_name} has completed a check-in")
        ).and_return({ success: true, message_id: '123456.789' })

        CheckIns::NotifyCompletionJob.perform_and_get_result(
          check_in_id: check_in.id,
          check_in_type: 'AssignmentCheckIn',
          completion_state: :employee_only,
          organization_id: organization.id
        )
      end

      it 'includes check-in show link in message' do
        expect(slack_service).to receive(:open_or_create_group_dm).and_return({ success: true, channel_id: 'D123456' })
        expect(slack_service).to receive(:post_group_dm) do |args|
          expect(args[:text]).to include('once')
          expect(args[:text]).to include(organization_company_teammate_check_ins_path(organization, employee_teammate))
          { success: true }
        end

        CheckIns::NotifyCompletionJob.perform_and_get_result(
          check_in_id: check_in.id,
          check_in_type: 'AssignmentCheckIn',
          completion_state: :employee_only,
          organization_id: organization.id
        )
      end
    end

    context 'when manager completes (one side done)' do
      before do
        manager_ct = CompanyTeammate.find(manager_teammate.id)
        check_in.update!(manager_completed_at: Time.current, manager_completed_by_teammate: manager_ct)
      end

      it 'sends group DM with manager name in message' do
        expect(slack_service).to receive(:open_or_create_group_dm).and_return({ success: true, channel_id: 'D123456' })
        expect(slack_service).to receive(:post_group_dm) do |args|
          expect(args[:text]).to include(manager.display_name)
          expect(args[:text]).to include('once')
          { success: true }
        end

        CheckIns::NotifyCompletionJob.perform_and_get_result(
          check_in_id: check_in.id,
          check_in_type: 'AssignmentCheckIn',
          completion_state: :manager_only,
          organization_id: organization.id
        )
      end
    end

    context 'when both complete' do
      before do
        manager_ct = CompanyTeammate.find(manager_teammate.id)
        check_in.update!(
          employee_completed_at: Time.current,
          manager_completed_at: Time.current,
          manager_completed_by_teammate: manager_ct
        )
      end

      it 'sends group DM with finalization link' do
        expect(slack_service).to receive(:open_or_create_group_dm).and_return({ success: true, channel_id: 'D123456' })
        expect(slack_service).to receive(:post_group_dm) do |args|
          expect(args[:text]).to include('we are now ready to review together')
          expect(args[:text]).to include(organization_company_teammate_finalization_path(organization, employee_teammate))
          { success: true }
        end

        CheckIns::NotifyCompletionJob.perform_and_get_result(
          check_in_id: check_in.id,
          check_in_type: 'AssignmentCheckIn',
          completion_state: :both_complete,
          organization_id: organization.id
        )
      end
    end

    context 'when employee does not have Slack' do
      before do
        employee_teammate.teammate_identities.slack.destroy_all
        check_in.update!(employee_completed_at: Time.current)
      end

      it 'does not send DM' do
        expect(slack_service).not_to receive(:open_or_create_group_dm)
        expect(slack_service).not_to receive(:post_group_dm)

        result = CheckIns::NotifyCompletionJob.perform_and_get_result(
          check_in_id: check_in.id,
          check_in_type: 'AssignmentCheckIn',
          completion_state: :employee_only,
          organization_id: organization.id
        )

        expect(result).to be_nil
      end
    end

    context 'when manager does not have Slack' do
      before do
        manager_teammate.teammate_identities.slack.destroy_all
        check_in.update!(employee_completed_at: Time.current)
      end

      it 'does not send DM' do
        expect(slack_service).not_to receive(:open_or_create_group_dm)
        expect(slack_service).not_to receive(:post_group_dm)

        result = CheckIns::NotifyCompletionJob.perform_and_get_result(
          check_in_id: check_in.id,
          check_in_type: 'AssignmentCheckIn',
          completion_state: :employee_only,
          organization_id: organization.id
        )

        expect(result).to be_nil
      end
    end

    context 'when manager is missing' do
      before do
        employee_teammate.employment_tenures.update_all(manager_teammate_id: nil)
        check_in.update!(employee_completed_at: Time.current)
      end

      it 'does not send DM' do
        expect(slack_service).not_to receive(:open_or_create_group_dm)

        result = CheckIns::NotifyCompletionJob.perform_and_get_result(
          check_in_id: check_in.id,
          check_in_type: 'AssignmentCheckIn',
          completion_state: :employee_only,
          organization_id: organization.id
        )

        expect(result).to be_nil
      end
    end
  end

  describe 'PositionCheckIn' do
    let!(:employment_tenure) { create(:employment_tenure, teammate: employee_teammate, company: organization, manager_teammate: manager_teammate) }
    let(:check_in) { create(:position_check_in, teammate: employee_teammate, employment_tenure: employment_tenure) }

    before do
      check_in.update!(employee_completed_at: Time.current)
    end

    it 'uses position display name in message' do
      expect(slack_service).to receive(:open_or_create_group_dm).and_return({ success: true, channel_id: 'D123456' })
      expect(slack_service).to receive(:post_group_dm) do |args|
        expect(args[:text]).to include(check_in.employment_tenure.position.display_name)
        { success: true }
      end

      CheckIns::NotifyCompletionJob.perform_and_get_result(
        check_in_id: check_in.id,
        check_in_type: 'PositionCheckIn',
        completion_state: :employee_only,
        organization_id: organization.id
      )
    end
  end

  describe 'AspirationCheckIn' do
    before do
      # Set up manager relationship for AspirationCheckIn specs
      create(:employment_tenure, teammate: employee_teammate, company: organization, manager_teammate: manager_teammate)
    end
    let(:aspiration) { create(:aspiration, organization: organization) }
    let(:check_in) { create(:aspiration_check_in, teammate: employee_teammate, aspiration: aspiration) }

    before do
      check_in.update!(employee_completed_at: Time.current)
    end

    it 'uses aspiration name in message' do
      expect(slack_service).to receive(:open_or_create_group_dm).and_return({ success: true, channel_id: 'D123456' })
      expect(slack_service).to receive(:post_group_dm) do |args|
        expect(args[:text]).to include(aspiration.name)
        { success: true }
      end

      CheckIns::NotifyCompletionJob.perform_and_get_result(
        check_in_id: check_in.id,
        check_in_type: 'AspirationCheckIn',
        completion_state: :employee_only,
        organization_id: organization.id
      )
    end
  end

  describe 'error handling' do
    before do
      # Set up manager relationship for error handling specs
      create(:employment_tenure, teammate: employee_teammate, company: organization, manager_teammate: manager_teammate)
    end
    let(:assignment) { create(:assignment, company: organization) }
    let(:check_in) { create(:assignment_check_in, teammate: employee_teammate, assignment: assignment) }

    before do
      check_in.update!(employee_completed_at: Time.current)
    end

    context 'when group DM creation fails' do
      it 'logs error and returns failure result' do
        expect(slack_service).to receive(:open_or_create_group_dm).and_return({ success: false, error: 'Failed to create DM' })
        expect(slack_service).not_to receive(:post_group_dm)

        result = CheckIns::NotifyCompletionJob.perform_and_get_result(
          check_in_id: check_in.id,
          check_in_type: 'AssignmentCheckIn',
          completion_state: :employee_only,
          organization_id: organization.id
        )

        expect(result).to be_nil
      end
    end

    context 'when check-in not found' do
      it 'handles gracefully' do
        expect(slack_service).not_to receive(:open_or_create_group_dm)

        result = CheckIns::NotifyCompletionJob.perform_and_get_result(
          check_in_id: 99999,
          check_in_type: 'AssignmentCheckIn',
          completion_state: :employee_only,
          organization_id: organization.id
        )

        expect(result[:success]).to be false
      end
    end
  end
end

