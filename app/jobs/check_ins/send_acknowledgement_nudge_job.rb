# frozen_string_literal: true

module CheckIns
  # Queued after a manager finalizes check-ins. Posts the same Slack acknowledgement
  # nudge as the nudges page. Finalization does not wait on Slack.
  class SendAcknowledgementNudgeJob < ApplicationJob
    queue_as :default

    def perform(organization_id:, employee_teammate_id:, nudger_company_teammate_id:)
      organization = Organization.find_by(id: organization_id)
      employee_teammate = CompanyTeammate.find_by(id: employee_teammate_id)
      nudger_company_teammate = CompanyTeammate.find_by(id: nudger_company_teammate_id)
      return unless organization && employee_teammate && nudger_company_teammate

      result = AcknowledgementNudgeService.call(
        organization: organization,
        employee_teammate: employee_teammate,
        nudger_company_teammate: nudger_company_teammate
      )
      return if result.ok?

      Rails.logger.info("Acknowledgement nudge not sent: #{result.error}")
    end
  end
end
