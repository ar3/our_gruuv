module CheckIns
  class NotifyCompletionJob < ApplicationJob
    queue_as :default

    def self.perform_and_get_result(check_in_id:, check_in_type:, completion_state:, organization_id:)
      job = new
      job.perform(check_in_id: check_in_id, check_in_type: check_in_type, completion_state: completion_state, organization_id: organization_id)
    end

    def perform(check_in_id:, check_in_type:, completion_state:, organization_id:)
      organization = Organization.find(organization_id)
      check_in = find_check_in(check_in_type, check_in_id)
      return unless check_in

      employee_teammate = check_in.teammate
      employee = employee_teammate.person
      
      # Get manager from active employment tenure in this organization
      employment_tenure = employee_teammate.employment_tenures.active.where(company: organization).first
      manager_teammate = employment_tenure&.manager_teammate
      return unless manager_teammate

      manager = manager_teammate.person

      # Both must have Slack connected for group DM
      return unless employee_teammate.has_slack_identity? && employee_teammate.slack_user_id.present?
      return unless manager_teammate.has_slack_identity? && manager_teammate.slack_user_id.present?

      slack_service = SlackService.new(organization)

      # Open or create group DM
      user_ids = [employee_teammate.slack_user_id, manager_teammate.slack_user_id]
      group_dm_result = slack_service.open_or_create_group_dm(user_ids: user_ids)

      unless group_dm_result[:success]
        Rails.logger.error "Failed to open group DM for check-in #{check_in_id}: #{group_dm_result[:error]}"
        return
      end

      # Build message
      message = build_message(check_in, employee, manager, completion_state, organization)

      # Send message to group DM
      result = slack_service.post_group_dm(channel_id: group_dm_result[:channel_id], text: message)

      unless result[:success]
        Rails.logger.error "Failed to post group DM for check-in #{check_in_id}: #{result[:error]}"
      end

      result
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.error "Check-in or organization not found: #{e.message}"
      { success: false, error: e.message }
    rescue => e
      Rails.logger.error "Unexpected error in NotifyCompletionJob: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      { success: false, error: "Unexpected error: #{e.message}" }
    end

    private

    def find_check_in(check_in_type, check_in_id)
      case check_in_type.to_s
      when 'AssignmentCheckIn'
        AssignmentCheckIn.find(check_in_id)
      when 'PositionCheckIn'
        PositionCheckIn.find(check_in_id)
      when 'AspirationCheckIn'
        AspirationCheckIn.find(check_in_id)
      else
        Rails.logger.error "Unknown check-in type: #{check_in_type}"
        nil
      end
    end

    def build_message(check_in, employee, manager, completion_state, organization)
      check_in_name = check_in_display_name(check_in)
      employee_name = employee.display_name || employee.preferred_name || employee.first_name
      manager_name = manager.display_name || manager.preferred_name || manager.first_name

      url_options = Rails.application.routes.default_url_options || {}
      
      employee_teammate = check_in.teammate
      
      case completion_state.to_sym
      when :both_complete
        completer_name = check_in.manager_completed_by_teammate == manager_teammate ? manager_name : employee_name
        link = Rails.application.routes.url_helpers.organization_company_teammate_finalization_url(
          organization,
          employee_teammate,
          url_options
        )
        "#{completer_name} has completed a check-in for #{check_in_name}... we are now ready to review together! #{link}"
      when :employee_only
        other_person_name = manager_name
        link = Rails.application.routes.url_helpers.organization_company_teammate_check_ins_url(
          organization,
          employee_teammate,
          url_options
        )
        "#{employee_name} has completed a check-in for #{check_in_name}... once #{other_person_name} is done, we can review together #{link}"
      when :manager_only
        other_person_name = employee_name
        link = Rails.application.routes.url_helpers.organization_company_teammate_check_ins_url(
          organization,
          employee_teammate,
          url_options
        )
        "#{manager_name} has completed a check-in for #{check_in_name}... once #{other_person_name} is done, we can review together #{link}"
      else
        Rails.logger.error "Unknown completion state: #{completion_state}"
        ""
      end
    end

    def check_in_display_name(check_in)
      case check_in
      when AssignmentCheckIn
        check_in.assignment.display_name
      when PositionCheckIn
        check_in.employment_tenure.position.display_name
      when AspirationCheckIn
        check_in.aspiration.name
      else
        "check-in"
      end
    end
  end
end

