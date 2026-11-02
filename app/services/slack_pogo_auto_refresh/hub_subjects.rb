# frozen_string_literal: true

module SlackPogoAutoRefresh
  # Self + current direct reports for a runner (hub coverage set).
  class HubSubjects
    def self.call(runner:)
      new(runner: runner).call
    end

    def initialize(runner:)
      @runner = runner
    end

    def call
      return [] if @runner.nil?

      ([@runner] + direct_reports).uniq
    end

    def direct_reports
      company = @runner.organization.company? ? @runner.organization : (@runner.organization.root_company || @runner.organization)
      ids = EmploymentTenure.where(company: company, manager_teammate: @runner, ended_at: nil).pluck(:teammate_id)
      CompanyTeammate.where(id: ids).includes(:person).to_a
    end
  end
end
