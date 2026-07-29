# frozen_string_literal: true

module PossibleObservationSlackSearches
  # Starts a 30-day Slack search + Sonnet auto-extract for each of a manager's direct reports.
  class BulkDirectReportsStarter
    WINDOW_DAYS = 30
    Result = Data.define(:ok?, :started_count, :searches, :error, :needs_slack_oauth)

    def self.call(...)
      new(...).call
    end

    def initialize(organization:, manager:)
      @organization = organization
      @manager = manager
    end

    def call
      return Result.new(ok?: false, started_count: 0, searches: [], error: "Sign in as a teammate in this organization.", needs_slack_oauth: false) if @manager.nil?
      return Result.new(ok?: false, started_count: 0, searches: [], error: "Connect Slack (search) first.", needs_slack_oauth: true) unless @manager.has_slack_search_identity?

      directs = direct_reports
      if directs.empty?
        return Result.new(ok?: false, started_count: 0, searches: [], error: "You have no direct reports to consult for.", needs_slack_oauth: false)
      end

      searches = directs.map { |subject| start_for(subject) }
      Result.new(ok?: true, started_count: searches.size, searches: searches, error: nil, needs_slack_oauth: false)
    end

    private

    def direct_reports
      company = @organization.company? ? @organization : (@organization.root_company || @organization)
      ids = EmploymentTenure.where(company: company, manager_teammate: @manager, ended_at: nil).pluck(:teammate_id)
      CompanyTeammate.where(id: ids).includes(:person).sort_by { |tm| tm.person.casual_name.to_s.downcase }
    end

    def start_for(subject)
      search = PossibleObservationSlackSearch.create!(
        organization: @organization,
        creator_company_teammate: @manager,
        subject_company_teammate: subject,
        window_days: WINDOW_DAYS,
        display_name: display_name_for(subject),
        search_status: "pending",
        extraction_status: "ready",
        auto_extract_after_search: true,
        auto_extract_model_id: Llm::SlackMomentsExtractor.stronger_model_id
      )
      PossibleObservationSlackSearchJob.perform_later(search.id)
      search
    end

    def display_name_for(subject)
      casual = subject.person.casual_name
      "Slack search about #{casual} (last #{WINDOW_DAYS} days) — #{Time.current.strftime('%Y-%m-%d %H:%M')}"
    end
  end
end
