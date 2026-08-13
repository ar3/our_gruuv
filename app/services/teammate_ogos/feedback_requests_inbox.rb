# frozen_string_literal: true

module TeammateOgos
  # Loads the teammate-scoped Feedback Requests inbox: four role sections in one scroll.
  class FeedbackRequestsInbox
    Section = Struct.new(
      :key,
      :title,
      :icon,
      :empty_heading,
      :empty_message,
      :rows,
      keyword_init: true
    )

    INCLUDES = [
      { requestor_teammate: :person },
      { subject_of_feedback_teammate: :person },
      { feedback_request_questions: [] },
      { responders: :person },
      { observations: [:observer, :observed_teammates] },
      :feedback_request_responders
    ].freeze

    def self.call(...) = new(...).call

    def initialize(organization:, teammate:, current_person:, viewing_company_teammate:, show_closed: false)
      @organization = organization
      @teammate = teammate
      @current_person = current_person
      @viewing_company_teammate = viewing_company_teammate
      @show_closed = show_closed
      @company = organization.root_company || organization
      @casual = teammate.person.casual_name
    end

    def call
      {
        show_closed: show_closed,
        sections: [
          waiting_section,
          about_section,
          asked_about_self_section,
          asked_for_others_section
        ]
      }
    end

    private

    attr_reader :organization, :teammate, :current_person, :viewing_company_teammate,
                :show_closed, :company, :casual

    def waiting_section
      scope = base_scope
        .joins(:feedback_request_responders)
        .where(feedback_request_responders: { teammate_id: teammate.id })
        .distinct

      unless show_closed
        scope = scope.where(feedback_request_responders: { completed_at: nil })
                     .where(feedback_requests: { deleted_at: nil })
      end

      build_section(
        key: :waiting,
        title: "Waiting on #{casual}",
        icon: "bi-inbox",
        empty_heading: "Nothing waiting on #{casual}",
        empty_message: "When someone asks #{casual} for feedback about a teammate, open requests show up here so they can respond.",
        scope: scope
      )
    end

    def about_section
      # Requests about this person that someone else created (on their behalf).
      scope = apply_open_or_closed(
        base_scope
          .where(subject_of_feedback_teammate_id: teammate.id)
          .where.not(requestor_teammate_id: teammate.id)
      )

      build_section(
        key: :about,
        title: "About #{casual}",
        icon: "bi-person",
        empty_heading: "No requests about #{casual}",
        empty_message: "When a manager or teammate requests feedback about #{casual} on their behalf, those requests appear here.",
        scope: scope
      )
    end

    def asked_about_self_section
      # They asked others for feedback about themselves.
      scope = apply_open_or_closed(
        base_scope.where(
          requestor_teammate_id: teammate.id,
          subject_of_feedback_teammate_id: teammate.id
        )
      )

      build_section(
        key: :asked_about_self,
        title: "#{casual} asked of others",
        icon: "bi-send",
        empty_heading: "#{casual} hasn't asked others for feedback yet",
        empty_message: "When #{casual} asks teammates for feedback about themselves, those requests appear here.",
        scope: scope
      )
    end

    def asked_for_others_section
      scope = apply_open_or_closed(
        base_scope
          .where(requestor_teammate_id: teammate.id)
          .where.not(subject_of_feedback_teammate_id: teammate.id)
      )

      build_section(
        key: :asked_for_others,
        title: "#{casual} asked for others",
        icon: "bi-people",
        empty_heading: "#{casual} hasn't requested feedback for others yet",
        empty_message: "When #{casual} requests feedback about someone else, those requests appear here so they can track progress.",
        scope: scope
      )
    end

    def build_section(key:, title:, icon:, empty_heading:, empty_message:, scope:)
      requests = scope.includes(*INCLUDES).order(created_at: :desc)
      Section.new(
        key: key,
        title: title,
        icon: icon,
        empty_heading: empty_heading,
        empty_message: empty_message,
        rows: requests.map { |request| row_for(request) }
      )
    end

    def row_for(request)
      FeedbackRequestRow.new(
        feedback_request: request,
        viewing_teammate: viewing_company_teammate,
        current_person: current_person,
        company: company
      )
    end

    def apply_open_or_closed(scope)
      return scope if show_closed

      scope.where(deleted_at: nil)
    end

    def base_scope
      return FeedbackRequest.none unless viewing_company_teammate

      scope = FeedbackRequest.where(company: company)
      return scope if can_view_full_inbox?

      pundit_user = OpenStruct.new(user: viewing_company_teammate, impersonating_teammate: nil)
      FeedbackRequestPolicy::Scope.new(pundit_user, scope).resolve
    end

    def can_view_full_inbox?
      viewing_company_teammate == teammate ||
        viewing_company_teammate.can_manage_employment? ||
        viewing_company_teammate.in_managerial_hierarchy_of?(teammate)
    end
  end
end
