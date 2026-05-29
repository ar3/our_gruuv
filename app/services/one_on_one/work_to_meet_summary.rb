# frozen_string_literal: true

require "set"

module OneOnOne
  # Centralizes Working-to-Meet check-in rows and tab badge state for the 1:1 Hub.
  class WorkToMeetSummary
    Row = Data.define(
      :associable,
      :check_in,
      :active_goal_count,
      :draft_goal_count,
      :has_active_goal,
      :ogo_count
    )

    Result = Data.define(
      :tab_variant,
      :tab_count,
      :essential_aspiration_rows,
      :essential_assignment_rows,
      :non_essential_assignment_rows
    )

    def self.call(organization:, teammate:, viewing_person:)
      new(organization: organization, teammate: teammate, viewing_person: viewing_person).call
    end

    def initialize(organization:, teammate:, viewing_person:)
      @organization = organization
      @teammate = teammate
      @viewing_person = viewing_person
    end

    def call
      essential_assignment_ids = essential_assignment_id_set
      goal_counts = goal_counts_by_associable

      essential_aspiration_rows = attach_ogo_counts(build_aspiration_rows(goal_counts))
      essential_assignment_rows = attach_ogo_counts(build_essential_assignment_rows(essential_assignment_ids, goal_counts))
      non_essential_assignment_rows = attach_ogo_counts(build_non_essential_assignment_rows(essential_assignment_ids, goal_counts))

      essential_wtm_rows = essential_aspiration_rows + essential_assignment_rows
      missing_goal_count = essential_wtm_rows.count { |row| !row.has_active_goal }

      tab_variant, tab_count =
        if essential_wtm_rows.empty?
          [:success, 0]
        elsif missing_goal_count.positive?
          [:danger, missing_goal_count]
        else
          [:info, essential_wtm_rows.size]
        end

      Result.new(
        tab_variant: tab_variant,
        tab_count: tab_count,
        essential_aspiration_rows: essential_aspiration_rows,
        essential_assignment_rows: essential_assignment_rows,
        non_essential_assignment_rows: non_essential_assignment_rows
      )
    end

    private

    attr_reader :organization, :teammate, :viewing_person

    def essential_assignment_id_set
      Set.new(relevant_assignment_ids)
    end

    def relevant_assignment_ids
      active_tenure = teammate.active_employment_tenure

      required_position_assignments = if active_tenure&.position
        active_tenure.position.required_assignments.includes(:assignment)
      else
        []
      end

      active_assignment_tenures = teammate.assignment_tenures
        .active_and_given_energy
        .includes(:assignment)
        .where(assignments: { company: teammate.organization })

      ids = Set.new
      required_position_assignments.each { |pa| ids.add(pa.assignment_id) }
      active_assignment_tenures.each { |at| ids.add(at.assignment_id) }
      ids.to_a
    end

    def goal_counts_by_associable
      rows = GoalAssociation
        .joins(:goal)
        .where(
          goals: {
            owner_type: "CompanyTeammate",
            owner_id: teammate.id,
            completed_at: nil,
            deleted_at: nil
          }
        )
        .pluck(:associable_type, :associable_id, "goals.started_at")

      active_counts = Hash.new(0)
      draft_counts = Hash.new(0)

      rows.each do |type, id, started_at|
        key = [type, id]
        if started_at.present?
          active_counts[key] += 1
        else
          draft_counts[key] += 1
        end
      end

      { active: active_counts, draft: draft_counts }
    end

    def row_for(associable, check_in, goal_counts, ogo_count: 0)
      key = [associable.class.name, associable.id]
      active_goal_count = goal_counts[:active][key] || 0
      draft_goal_count = goal_counts[:draft][key] || 0

      Row.new(
        associable: associable,
        check_in: check_in,
        active_goal_count: active_goal_count,
        draft_goal_count: draft_goal_count,
        has_active_goal: active_goal_count.positive?,
        ogo_count: ogo_count
      )
    end

    def attach_ogo_counts(rows)
      counts = ogo_counts_by_associable(rows.map(&:associable))
      rows.map do |row|
        key = [row.associable.class.name, row.associable.id]
        row.with(ogo_count: counts[key] || 0)
      end
    end

    def ogo_counts_by_associable(associables)
      return {} if associables.empty?

      assignment_ids = associables.grep(Assignment).map(&:id).uniq
      aspiration_ids = associables.grep(Aspiration).map(&:id).uniq
      counts = Hash.new(0)

      base_scope = visible_ogo_scope

      if assignment_ids.any?
        base_scope
          .where(observation_ratings: { rateable_type: "Assignment", rateable_id: assignment_ids })
          .group("observation_ratings.rateable_id")
          .count("DISTINCT observations.id")
          .each { |id, count| counts[["Assignment", id]] = count }
      end

      if aspiration_ids.any?
        base_scope
          .where(observation_ratings: { rateable_type: "Aspiration", rateable_id: aspiration_ids })
          .group("observation_ratings.rateable_id")
          .count("DISTINCT observations.id")
          .each { |id, count| counts[["Aspiration", id]] = count }
      end

      counts
    end

    def visible_ogo_scope
      ObservationVisibilityQuery.new(viewing_person, organization)
        .visible_observations
        .joins(:observees, :observation_ratings)
        .merge(Observation.published)
        .merge(Observation.not_journal)
        .where(observees: { teammate_id: teammate.id })
    end

    def build_aspiration_rows(goal_counts)
      latest_by_aspiration = latest_aspiration_check_ins_by_id

      Aspiration.within_hierarchy(organization).ordered.filter_map do |aspiration|
        check_in = latest_by_aspiration[aspiration.id]
        next unless check_in&.official_rating == "working_to_meet"

        row_for(aspiration, check_in, goal_counts)
      end
    end

    def build_essential_assignment_rows(essential_assignment_ids, goal_counts)
      latest_by_assignment = latest_assignment_check_ins_by_id

      essential_assignment_ids.filter_map do |assignment_id|
        check_in = latest_by_assignment[assignment_id]
        next unless check_in&.official_rating == "working_to_meet"

        assignment = assignments_by_id[assignment_id]
        next if assignment.blank?

        row_for(assignment, check_in, goal_counts)
      end.sort_by { |row| row.associable.title.downcase }
    end

    def build_non_essential_assignment_rows(essential_assignment_ids, goal_counts)
      latest_by_assignment = latest_assignment_check_ins_by_id

      latest_by_assignment.filter_map do |assignment_id, check_in|
        next if essential_assignment_ids.include?(assignment_id)
        next unless check_in.official_rating == "working_to_meet"

        assignment = assignments_by_id[assignment_id]
        next if assignment.blank?

        row_for(assignment, check_in, goal_counts)
      end.sort_by { |row| row.associable.title.downcase }
    end

    def latest_assignment_check_ins_by_id
      @latest_assignment_check_ins_by_id ||= AssignmentCheckIn
        .where(company_teammate: teammate)
        .closed
        .order(official_check_in_completed_at: :desc)
        .index_by(&:assignment_id)
    end

    def latest_aspiration_check_ins_by_id
      @latest_aspiration_check_ins_by_id ||= AspirationCheckIn
        .where(company_teammate: teammate)
        .closed
        .order(official_check_in_completed_at: :desc)
        .index_by(&:aspiration_id)
    end

    def assignments_by_id
      @assignments_by_id ||= begin
        ids = latest_assignment_check_ins_by_id.keys
        Assignment.where(id: ids).index_by(&:id)
      end
    end
  end
end
