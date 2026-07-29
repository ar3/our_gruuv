# frozen_string_literal: true

module Organizations
  # Starts 30-day Slack search + Sonnet extract for each of the viewing manager's direct reports.
  class DirectReportsSlackOgoConsultsController < OrganizationNamespaceBaseController
    before_action :authenticate_person!
    after_action :verify_authorized

    def create
      authorize PossibleObservationSlackSearch, :create?

      unless current_company_teammate&.has_direct_reports?
        redirect_to my_employees_directory_path(organization),
                    alert: "You need direct reports to run this bulk consultation."
        return
      end

      result = PossibleObservationSlackSearches::BulkDirectReportsStarter.call(
        organization: organization,
        manager: current_company_teammate
      )

      if result.needs_slack_oauth
        redirect_to my_employees_directory_path(organization),
                    alert: result.error.presence || "Connect Slack (search) before running bulk consultations."
        return
      end

      unless result.ok?
        redirect_to my_employees_directory_path(organization), alert: result.error
        return
      end

      redirect_to organization_possible_observation_consults_path(organization),
                  notice: bulk_notice(result.started_count)
    end

    private

    def bulk_notice(count)
      hub = "Consult OG to find potential OGOs"
      "Started #{count} Slack #{'consultation'.pluralize(count)} for your direct reports " \
        "(last 30 days, stronger model). This may take a while — each person finishes separately. " \
        "Watch progress and open results on #{hub}."
    end
  end
end
