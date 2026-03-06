# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CheckIns::NotifyCompletionJob, type: :job do
  let(:organization) { create(:organization, :company) }
  let(:employee) { create(:person) }
  let(:manager) { create(:person) }
  let(:employee_teammate) { create(:teammate, person: employee, organization: organization) }
  let(:manager_teammate) { CompanyTeammate.create!(person: manager, organization: organization) }
  let(:slack_service) { instance_double(SlackService) }

  before do
    create(:teammate_identity, :slack, teammate: employee_teammate, uid: 'U123456')
    create(:teammate_identity, :slack, teammate: manager_teammate, uid: 'U789012')

    allow(SlackService).to receive(:new).and_return(slack_service)
  end

  describe 'AssignmentCheckIn' do
    before do
      create(:employment_tenure,
        teammate: employee_teammate,
        company: organization,
        manager_teammate: manager_teammate,
        started_at: 1.month.ago,
        ended_at: nil)
    end
    let(:assignment) { create(:assignment, company: organization) }
    let(:check_in) { create(:assignment_check_in, teammate: employee_teammate, assignment: assignment) }

    context 'when employee completes (first in hour - creates batch and main message)' do
      before do
        check_in.update!(employee_completed_at: Time.current, updated_at: Time.current)
      end

      it 'opens group DM, posts main message, and posts thread message for the check-in' do
        expect(slack_service).to receive(:open_or_create_group_dm).with(
          user_ids: ['U123456', 'U789012']
        ).and_return({ success: true, channel_id: 'D123456' })

        expect(slack_service).to receive(:post_group_dm).with(
          channel_id: 'D123456',
          text: include("#{employee.casual_name} has completed a check-in!")
        ).and_return({ success: true, message_id: '123456.789' })

        expect(slack_service).to receive(:post_message_to_thread).with(
          channel_id: 'D123456',
          thread_ts: '123456.789',
          text: include(employee.casual_name).and(include('waiting on')).and(include(manager.casual_name))
        ).and_return({ success: true })

        CheckIns::NotifyCompletionJob.perform_and_get_result(
          check_in_id: check_in.id,
          check_in_type: 'AssignmentCheckIn',
          completion_state: :employee_only,
          organization_id: organization.id
        )
      end

      it 'creates a batch and notification linked to it' do
        allow(slack_service).to receive(:open_or_create_group_dm).and_return({ success: true, channel_id: 'D123456' })
        allow(slack_service).to receive(:post_group_dm).and_return({ success: true, message_id: '123456.789' })
        allow(slack_service).to receive(:post_message_to_thread).and_return({ success: true })

        expect {
          CheckIns::NotifyCompletionJob.perform_and_get_result(
            check_in_id: check_in.id,
            check_in_type: 'AssignmentCheckIn',
            completion_state: :employee_only,
            organization_id: organization.id
          )
        }.to change(CheckInCompletionNotificationBatch, :count).by(1).and change(Notification, :count).by(1)

        batch = CheckInCompletionNotificationBatch.last
        expect(batch.notification_id).to be_present
        expect(batch.action_taker_teammate_id).to eq(employee_teammate.id)
        notification = batch.notification
        expect(notification.notification_type).to eq('check_in_completion')
        expect(notification.fallback_text).to include('See the thread for all')
        expect(notification.fallback_text).to include('check-ins')
      end

      it 'main message includes link to employee check-ins page' do
        allow(slack_service).to receive(:open_or_create_group_dm).and_return({ success: true, channel_id: 'D123456' })
        allow(slack_service).to receive(:post_message_to_thread).and_return({ success: true })

        expect(slack_service).to receive(:post_group_dm) do |args|
          check_ins_path = organization_company_teammate_check_ins_path(organization, employee_teammate)
          expect(args[:text]).to include(check_ins_path)
          expect(args[:text]).to include('check-ins')
          { success: true, message_id: '123456.789' }
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
        check_in.update!(manager_completed_at: Time.current, manager_completed_by_teammate: manager_ct, updated_at: Time.current)
      end

      it 'main message states manager casual name and thread says waiting on employee' do
        allow(slack_service).to receive(:open_or_create_group_dm).and_return({ success: true, channel_id: 'D123456' })
        allow(slack_service).to receive(:post_message_to_thread).and_return({ success: true })

        expect(slack_service).to receive(:post_group_dm) do |args|
          expect(args[:text]).to start_with("#{manager.casual_name} has completed a check-in!")
          { success: true, message_id: '123456.789' }
        end

        expect(slack_service).to receive(:post_message_to_thread) do |args|
          expect(args[:text]).to include(manager.casual_name)
          expect(args[:text]).to include('waiting on')
          expect(args[:text]).to include(employee.casual_name)
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
          employee_completed_at: 2.hours.ago,
          manager_completed_at: 1.hour.ago,
          manager_completed_by_teammate: manager_ct,
          updated_at: Time.current
        )
      end

      it 'thread message includes assignment name and review this together link' do
        allow(slack_service).to receive(:open_or_create_group_dm).and_return({ success: true, channel_id: 'D123456' })
        allow(slack_service).to receive(:post_group_dm).and_return({ success: true, message_id: '123456.789' })

        expect(slack_service).to receive(:post_message_to_thread) do |args|
          expect(args[:text]).to include('have both checked in')
          expect(args[:text]).to include(check_in.assignment.display_name)
          expect(args[:text]).to include('review this together')
          finalization_path = organization_company_teammate_finalization_path(organization, employee_teammate)
          expect(args[:text]).to include(finalization_path)
          { success: true }
        end

        CheckIns::NotifyCompletionJob.perform_and_get_result(
          check_in_id: check_in.id,
          check_in_type: 'AssignmentCheckIn',
          completion_state: :both_complete,
          organization_id: organization.id
        )
      end

      it 'states manager as action taker when manager_completed_at is latest' do
        allow(slack_service).to receive(:open_or_create_group_dm).and_return({ success: true, channel_id: 'D123456' })
        allow(slack_service).to receive(:post_message_to_thread).and_return({ success: true })

        expect(slack_service).to receive(:post_group_dm) do |args|
          expect(args[:text]).to start_with("#{manager.casual_name} has completed a check-in!")
          { success: true, message_id: '123456.789' }
        end

        CheckIns::NotifyCompletionJob.perform_and_get_result(
          check_in_id: check_in.id,
          check_in_type: 'AssignmentCheckIn',
          completion_state: :both_complete,
          organization_id: organization.id
        )
      end

      it 'states employee as action taker when employee_completed_at is latest' do
        check_in.update!(employee_completed_at: 1.hour.ago, manager_completed_at: 2.hours.ago)

        allow(slack_service).to receive(:open_or_create_group_dm).and_return({ success: true, channel_id: 'D123456' })
        allow(slack_service).to receive(:post_message_to_thread).and_return({ success: true })

        expect(slack_service).to receive(:post_group_dm) do |args|
          expect(args[:text]).to start_with("#{employee.casual_name} has completed a check-in!")
          { success: true, message_id: '123456.789' }
        end

        CheckIns::NotifyCompletionJob.perform_and_get_result(
          check_in_id: check_in.id,
          check_in_type: 'AssignmentCheckIn',
          completion_state: :both_complete,
          organization_id: organization.id
        )
      end
    end

    context 'when batch already exists for same hour and action taker' do
      before do
        check_in.update!(employee_completed_at: Time.current, updated_at: Time.current)
      end

      it 'updates main message with Latest update and posts new thread message for new check-in' do
        hour_marker = Time.current.utc.beginning_of_hour
        batch = CheckInCompletionNotificationBatch.create!(
          organization: organization,
          hour_marker: hour_marker,
          employee_teammate: employee_teammate,
          manager_teammate: manager_teammate,
          action_taker_teammate: employee_teammate
        )
        notification = Notification.create!(
          notifiable: batch,
          notification_type: 'check_in_completion',
          status: 'sent_successfully',
          message_id: '111.222',
          metadata: { 'channel' => 'D123456', 'thread_check_in_keys' => [] },
          fallback_text: "#{employee.casual_name} has completed a check-in! See the thread for all check-ins waiting."
        )
        batch.update!(notification_id: notification.id)

        expect(slack_service).not_to receive(:open_or_create_group_dm)
        expect(slack_service).not_to receive(:post_group_dm)

        expect(slack_service).to receive(:post_message_to_thread).with(
          channel_id: 'D123456',
          thread_ts: '111.222',
          text: include(employee.casual_name).and(include('waiting on'))
        ).and_return({ success: true })

        expect(slack_service).to receive(:update_group_dm_message).with(
          channel_id: 'D123456',
          message_ts: '111.222',
          text: include('Latest update was')
        ).and_return({ success: true })

        CheckIns::NotifyCompletionJob.perform_and_get_result(
          check_in_id: check_in.id,
          check_in_type: 'AssignmentCheckIn',
          completion_state: :employee_only,
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
      check_in.update!(employee_completed_at: Time.current, updated_at: Time.current)
    end

    it 'thread message uses position display name' do
      allow(slack_service).to receive(:open_or_create_group_dm).and_return({ success: true, channel_id: 'D123456' })
      allow(slack_service).to receive(:post_group_dm).and_return({ success: true, message_id: '123456.789' })

      expect(slack_service).to receive(:post_message_to_thread) do |args|
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
      create(:employment_tenure, teammate: employee_teammate, company: organization, manager_teammate: manager_teammate)
    end
    let(:aspiration) { create(:aspiration, company: organization) }
    let(:check_in) { create(:aspiration_check_in, teammate: employee_teammate, aspiration: aspiration) }

    before do
      check_in.update!(employee_completed_at: Time.current, updated_at: Time.current)
    end

    it 'thread message uses aspiration name' do
      allow(slack_service).to receive(:open_or_create_group_dm).and_return({ success: true, channel_id: 'D123456' })
      allow(slack_service).to receive(:post_group_dm).and_return({ success: true, message_id: '123456.789' })

      expect(slack_service).to receive(:post_message_to_thread) do |args|
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
      create(:employment_tenure, teammate: employee_teammate, company: organization, manager_teammate: manager_teammate)
    end
    let(:assignment) { create(:assignment, company: organization) }
    let(:check_in) { create(:assignment_check_in, teammate: employee_teammate, assignment: assignment) }

    before do
      check_in.update!(employee_completed_at: Time.current, updated_at: Time.current)
    end

    context 'when group DM creation fails' do
      it 'returns failure result' do
        expect(slack_service).to receive(:open_or_create_group_dm).and_return({ success: false, error: 'Failed to create DM' })
        expect(slack_service).not_to receive(:post_group_dm)

        result = CheckIns::NotifyCompletionJob.perform_and_get_result(
          check_in_id: check_in.id,
          check_in_type: 'AssignmentCheckIn',
          completion_state: :employee_only,
          organization_id: organization.id
        )

        expect(result[:success]).to be false
        expect(result[:error]).to include('Failed to create')
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
