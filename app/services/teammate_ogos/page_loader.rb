# frozen_string_literal: true

module TeammateOgos
  class PageLoader
    LIST_LIMIT = 50
    THIRTY_DAYS_AGO = 30.days.ago

    def self.call(...) = new(...).call

    def initialize(organization:, teammate:, current_person:, viewing_company_teammate:, one_on_one_link:, active_tab:)
      @organization = organization
      @teammate = teammate
      @current_person = current_person
      @viewing_company_teammate = viewing_company_teammate
      @one_on_one_link = one_on_one_link
      @active_tab = active_tab
      @company = organization.root_company || organization
    end

    def call
      {
        observation_health: load_observation_health,
        about_counts: load_about_counts,
        from_counts: load_from_counts,
        observations_involving_url: observations_involving_url,
        observations: load_observations_for_tab,
        feedback_requests: load_feedback_requests,
        feedback_request_rows: load_feedback_request_rows,
        open_respondent_requests: load_open_respondent_requests
      }
    end

    private

    attr_reader :organization, :teammate, :current_person, :viewing_company_teammate,
                :one_on_one_link, :active_tab, :company

    def load_observation_health
      return nil if active_tab == :source_from_slack

      OneOnOne::PriorityCarouselBuilder.observation_health(
        organization: organization,
        teammate: teammate,
        one_on_one_link: one_on_one_link,
        viewing_company_teammate: viewing_company_teammate
      )
    end

    def about_scope
      @about_scope ||= Observations::HealthScopes.received_scope_for_person(
        teammate,
        organization,
        current_person: current_person
      )
    end

    def from_scope
      @from_scope ||= begin
        scope = Observations::HealthScopes.given_scope_for_person(
          teammate,
          organization,
          current_person: current_person
        )
        self_observation_ids = Observation
          .joins(:observees)
          .where(observer_id: teammate.person_id)
          .where(observees: { teammate_id: teammate.id })
          .select(:id)
        scope.where.not(id: self_observation_ids)
      end
    end

    def load_about_counts
      scope = about_scope
      {
        last_30_days: scope.where(observed_at: THIRTY_DAYS_AGO..).count,
        older_than_30_days: scope.where(observed_at: ...THIRTY_DAYS_AGO).count,
        total: scope.count
      }
    end

    def load_from_counts
      scope = from_scope
      {
        last_30_days: scope.where(observed_at: THIRTY_DAYS_AGO..).count,
        older_than_30_days: scope.where(observed_at: ...THIRTY_DAYS_AGO).count,
        total: scope.count
      }
    end

    def observations_involving_url
      return nil unless current_person && Pundit.policy(pundit_user, company).view_observations?

      Rails.application.routes.url_helpers.organization_observations_path(
        organization,
        involving_teammate_id: teammate.id,
        view: "large_list",
        return_url: current_story_path,
        return_text: "Back to #{teammate.person.casual_name}'s OGOs"
      )
    end

    def load_observations_for_tab
      scope =
        case active_tab
        when :from
          from_scope
        when :about
          about_scope
        else
          return Observation.none
        end

      scope
        .includes(:observer, :observed_teammates, :observation_ratings, :feedback_request_question)
        .order(observed_at: :desc)
        .limit(LIST_LIMIT)
    end

    def feedback_requests_scope
      return FeedbackRequest.none unless viewing_company_teammate

      scope = FeedbackRequest.where(company: company, subject_of_feedback_teammate_id: teammate.id)
      unless can_view_all_story_feedback_requests?
        pundit_user = OpenStruct.new(user: viewing_company_teammate, impersonating_teammate: nil)
        policy = FeedbackRequestPolicy::Scope.new(pundit_user, FeedbackRequest)
        scope = policy.resolve.where(subject_of_feedback_teammate_id: teammate.id)
      end

      scope.includes(
        :requestor_teammate,
        :subject_of_feedback_teammate,
        { feedback_request_questions: [] },
        :responders,
        { observations: [:observer, :observed_teammates] }
      ).order(created_at: :desc)
    end

    def can_view_all_story_feedback_requests?
      viewing_company_teammate == teammate ||
        viewing_company_teammate.can_manage_employment? ||
        viewing_company_teammate.in_managerial_hierarchy_of?(teammate)
    end

    def load_feedback_requests
      feedback_requests_scope
    end

    def load_feedback_request_rows
      feedback_requests_scope.map do |request|
        FeedbackRequestRow.new(
          feedback_request: request,
          viewing_teammate: viewing_company_teammate,
          current_person: current_person,
          company: company
        )
      end
    end

    def load_open_respondent_requests
      return FeedbackRequest.none unless viewing_company_teammate

      FeedbackRequest
        .joins(:feedback_request_responders)
        .where(company: company, subject_of_feedback_teammate_id: teammate.id)
        .where(feedback_request_responders: { teammate_id: viewing_company_teammate.id, completed_at: nil })
        .where(feedback_requests: { deleted_at: nil })
        .includes(:requestor_teammate, :subject_of_feedback_teammate)
        .distinct
    end

    def current_story_path
      helpers = Rails.application.routes.url_helpers
      case active_tab
      when :from
        helpers.ogos_from_organization_company_teammate_path(organization, teammate)
      when :feedback_requests
        helpers.ogos_feedback_requests_organization_company_teammate_path(organization, teammate)
      when :source_from_slack
        helpers.ogos_source_from_slack_organization_company_teammate_path(organization, teammate)
      else
        helpers.ogos_organization_company_teammate_path(organization, teammate)
      end
    end

    def pundit_user
      OpenStruct.new(user: viewing_company_teammate, impersonating_teammate: nil)
    end
  end
end
