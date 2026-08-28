# frozen_string_literal: true

module Teams
  class AssignmentRoster
    CovererStatus = Struct.new(:coverer, :missing_tenure, :not_team_member, keyword_init: true)
    Row = Struct.new(
      :need,
      :assignment,
      :coverer_statuses,
      :could_cover_teammates,
      keyword_init: true
    )

    def initialize(team)
      @team = team
    end

    def required_rows
      rows_for(TeamAssignmentNeed.required)
    end

    def nice_to_have_rows
      rows_for(TeamAssignmentNeed.nice_to_have)
    end

    def any_needs?
      needs_scope.exists?
    end

    private

    def needs_scope
      @team.team_assignment_needs.ordered_by_assignment_title
        .includes(:assignment, team_assignment_coverers: { company_teammate: :person })
    end

    def rows_for(scope)
      needs = needs_scope.merge(scope).to_a
      assignment_ids = needs.map(&:assignment_id)
      tenure_holder_ids_by_assignment = active_tenure_holder_ids_by_assignment(assignment_ids)
      team_member_ids = @team.team_members.pluck(:company_teammate_id).to_set

      needs.map do |need|
        tenure_holder_ids = tenure_holder_ids_by_assignment.fetch(need.assignment_id, Set.new)
        coverer_statuses = need.team_assignment_coverers.map do |coverer|
          teammate_id = coverer.company_teammate_id
          CovererStatus.new(
            coverer: coverer,
            missing_tenure: !tenure_holder_ids.include?(teammate_id),
            not_team_member: !team_member_ids.include?(teammate_id)
          )
        end

        could_cover_teammate_ids = tenure_holder_ids & team_member_ids
        could_cover_teammates = CompanyTeammate.where(id: could_cover_teammate_ids.to_a)
          .includes(:person)
          .sort_by { |teammate| teammate.person.last_name.to_s.downcase }

        Row.new(
          need: need,
          assignment: need.assignment,
          coverer_statuses: coverer_statuses,
          could_cover_teammates: could_cover_teammates
        )
      end
    end

    def active_tenure_holder_ids_by_assignment(assignment_ids)
      return {} if assignment_ids.empty?

      AssignmentTenure.active
        .where(assignment_id: assignment_ids)
        .pluck(:assignment_id, :teammate_id)
        .each_with_object(Hash.new { |hash, key| hash[key] = Set.new }) do |(assignment_id, teammate_id), hash|
          hash[assignment_id] << teammate_id
        end
    end
  end
end
