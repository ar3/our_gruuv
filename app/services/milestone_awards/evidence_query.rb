# frozen_string_literal: true

module MilestoneAwards
  # Evidence package for milestone award / co-sign pages.
  class EvidenceQuery
    AssignmentRow = Data.define(:assignment, :url, :recent_check_ins)
    CheckInSnippet = Data.define(:rating_label, :completed_at)

    def self.call(...) = new(...).call

    def initialize(organization:, viewer_person:, viewing_teammate:, teammate:, ability:,
                   routes: Rails.application.routes.url_helpers)
      @organization = organization
      @viewer_person = viewer_person
      @viewing_teammate = viewing_teammate
      @teammate = teammate
      @ability = ability
      @routes = routes
    end

    def call
      {
        observations: observations,
        observations_index_path: observations_index_path,
        can_view_assignment_check_ins: can_view_assignment_check_ins?,
        assignment_check_ins_denied_message: assignment_check_ins_denied_message,
        assignment_rows: can_view_assignment_check_ins? ? assignment_rows : []
      }
    end

    private

    def observations
      visibility = ObservationVisibilityQuery.new(@viewer_person, @organization)

      scope = Observation
        .where(company: @organization)
        .joins(:observees, :observation_ratings)
        .where(observees: { teammate_id: @teammate.id })
        .where(observation_ratings: { rateable_type: "Ability", rateable_id: @ability.id })
        .includes(:observer, :observed_teammates, :observation_ratings)
        .distinct
        .order(observed_at: :desc)
        .limit(50)

      scope.select { |obs| visibility.visible_to?(obs) }.first(15)
    end

    def observations_index_path
      @routes.organization_observations_path(
        @organization,
        observee_ids: [@teammate.id],
        rateable_type: "Ability",
        rateable_id: @ability.id
      )
    end

    def can_view_assignment_check_ins?
      return false if @viewing_teammate.blank?
      return true if @viewing_teammate.person&.og_admin?
      return true if @viewing_teammate.can_manage_employment?
      return true if @viewing_teammate.in_managerial_hierarchy_of?(@teammate)

      false
    end

    def assignment_check_ins_denied_message
      return nil if can_view_assignment_check_ins?

      "You don't have access to assignment check-ins for this teammate because you are not in " \
        "their management chain and do not have Manage employment permission."
    end

    def assignment_rows
      tenures = AssignmentTenure
        .active
        .where(teammate_id: @teammate.id)
        .joins(assignment: :assignment_abilities)
        .where(assignment_abilities: { ability_id: @ability.id })
        .includes(:assignment)
        .distinct

      tenures.map do |tenure|
        assignment = tenure.assignment
        check_ins = AssignmentCheckIn
          .where(company_teammate: @teammate, assignment: assignment)
          .closed
          .order(official_check_in_completed_at: :desc)
          .limit(2)

        AssignmentRow.new(
          assignment: assignment,
          url: @routes.organization_teammate_assignment_path(@organization, @teammate, assignment),
          recent_check_ins: check_ins.map do |ci|
            CheckInSnippet.new(
              rating_label: check_in_rating_label(ci),
              completed_at: ci.official_check_in_completed_at
            )
          end
        )
      end.sort_by { |row| row.assignment.title.to_s.downcase }
    end

    def check_in_rating_label(check_in)
      rating = check_in.official_rating.presence || check_in.manager_rating.presence || check_in.employee_rating.presence
      data = CheckInHelper::ASSIGNMENT_RATINGS[rating.to_s]
      return check_in.rating_display if data.blank?

      "#{data[:emoji]} #{data[:label]} Expectations of this Assignment"
    end
  end
end
