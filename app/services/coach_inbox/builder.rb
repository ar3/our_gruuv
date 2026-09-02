# frozen_string_literal: true

module CoachInbox
  # Validation Coach Inbox: outstanding coachables for a manager-scoped teammate set.
  # Counts always; item rows only for expanded subtypes.
  class Builder
    Item = Data.define(:id, :subtype_key, :teammate_id, :person_name, :title, :subtitle, :url)
    SubtypeSummary = Data.define(:key, :label, :count, :items, :expanded)
    Section = Data.define(:key, :label, :subtypes)

    SECTION_DEFS = [
      { key: :check_ins, label: "Check-ins" },
      { key: :ogos, label: "OGOs" },
      { key: :goals, label: "Goals" },
      { key: :expectation_alignment, label: "Expectation Alignment" }
    ].freeze

    OGO_COMMENT_LOOKBACK = 90.days
    MAAP_COMMENT_TYPES = %w[Assignment Position Ability].freeze

    def self.call(organization:, teammates:, expanded_subtype_keys: [], routes: Rails.application.routes.url_helpers)
      new(
        organization: organization,
        teammates: teammates,
        expanded_subtype_keys: expanded_subtype_keys,
        routes: routes
      ).call
    end

    def initialize(organization:, teammates:, expanded_subtype_keys:, routes:)
      @organization = organization
      @teammates = Array(teammates).compact
      @teammate_ids = @teammates.map(&:id)
      @teammates_by_id = @teammates.index_by(&:id)
      @expanded = Array(expanded_subtype_keys).map(&:to_s).to_set
      @routes = routes
    end

    def call
      SECTION_DEFS.map { |defn| build_section(defn) }
    end

    private

    attr_reader :organization, :teammates, :teammate_ids, :teammates_by_id, :expanded, :routes

    def build_section(defn)
      Section.new(
        key: defn[:key],
        label: defn[:label],
        subtypes: send(:"#{defn[:key]}_subtypes")
      )
    end

    def subtype_summary(key, label, items:, count: nil)
      key = key.to_sym
      is_expanded = expanded.include?(key.to_s)
      SubtypeSummary.new(
        key: key,
        label: label,
        count: count.nil? ? items.size : count,
        items: is_expanded ? items : [],
        expanded: is_expanded
      )
    end

    def check_ins_subtypes
      employee_items = incomplete_check_in_items(side: :employee)
      manager_items = incomplete_check_in_items(side: :manager)
      ack_counts = CheckIns::AcknowledgementQueue.pending_counts_by_teammate_id(teammate_ids: teammate_ids)
      ack_items = expanded.include?("pending_acknowledgements") ? acknowledgement_items(ack_counts) : []

      [
        subtype_summary(:incomplete_employee_side, "Incomplete — employee side", items: employee_items),
        subtype_summary(:incomplete_manager_side, "Incomplete — manager side", items: manager_items),
        subtype_summary(
          :pending_acknowledgements,
          "Pending acknowledgements",
          items: ack_items,
          count: ack_counts.values.sum
        )
      ]
    end

    def ogos_subtypes
      [
        subtype_summary(:open_feedback_responses, "Open feedback request responses", items: feedback_request_items),
        subtype_summary(:ogo_comments, "OGO comments (need attention)", items: ogo_comment_items)
      ]
    end

    def goals_subtypes
      [
        subtype_summary(:goal_confidence, "Goal confidence due", items: goal_confidence_items),
        subtype_summary(:wtm_missing_goals, "Missing goals on WTM assignments / values", items: wtm_missing_goal_items),
        subtype_summary(:milestone_gap_missing_goals, "Missing goals on milestone gaps", items: milestone_gap_missing_goal_items)
      ]
    end

    def expectation_alignment_subtypes
      [
        subtype_summary(
          :unresolved_maap_comments,
          "Unresolved comments on assignments, positions, abilities",
          items: maap_unresolved_comment_items
        )
      ]
    end

    # --- Check-ins ---

    def incomplete_check_in_items(side:)
      scope_method = side == :employee ? :awaiting_employee_input : :awaiting_manager_input
      label = side == :employee ? "Employee side open" : "Manager side open"
      subtype = side == :employee ? :incomplete_employee_side : :incomplete_manager_side

      includes_map = {
        AssignmentCheckIn => [:company_teammate, :assignment],
        AspirationCheckIn => [:company_teammate, :aspiration],
        PositionCheckIn => { company_teammate: [], employment_tenure: :position }
      }

      [AssignmentCheckIn, AspirationCheckIn, PositionCheckIn].flat_map do |klass|
        klass.where(teammate_id: teammate_ids).public_send(scope_method).includes(includes_map[klass]).filter_map do |ci|
          teammate = teammates_by_id[ci.teammate_id]
          next unless teammate

          Item.new(
            id: "check_in-#{klass.name}-#{ci.id}",
            subtype_key: subtype,
            teammate_id: teammate.id,
            person_name: person_name_for(teammate),
            title: check_in_title(ci),
            subtitle: label,
            url: routes.organization_company_teammate_check_ins_path(organization, teammate)
          )
        end
      end
    end

    def acknowledgement_items(ack_counts)
      return [] if teammate_ids.empty?

      ack_counts.filter_map do |tid, count|
        next unless count.to_i.positive?

        teammate = teammates_by_id[tid]
        next unless teammate

        Item.new(
          id: "ack-#{tid}",
          subtype_key: :pending_acknowledgements,
          teammate_id: tid,
          person_name: person_name_for(teammate),
          title: "#{count} pending acknowledgement#{'s' if count != 1}",
          subtitle: "Finalized clarity snapshots awaiting acknowledgement",
          url: routes.acknowledge_organization_company_teammate_check_ins_path(organization, teammate)
        )
      end
    end

    def check_in_title(check_in)
      case check_in
      when AssignmentCheckIn
        check_in.assignment&.title || "Assignment check-in"
      when AspirationCheckIn
        check_in.aspiration&.name || "Values check-in"
      when PositionCheckIn
        check_in.employment_tenure&.position&.display_name || "Position check-in"
      else
        "Check-in"
      end
    end

    # --- OGOs ---

    def feedback_request_items
      return [] if teammate_ids.empty?

      FeedbackRequestResponder
        .joins(:feedback_request)
        .includes(:company_teammate, :feedback_request)
        .where(teammate_id: teammate_ids, completed_at: nil)
        .merge(FeedbackRequest.not_deleted)
        .filter_map do |responder|
          teammate = teammates_by_id[responder.teammate_id]
          next unless teammate

          fr = responder.feedback_request
          Item.new(
            id: "fr-#{responder.id}",
            subtype_key: :open_feedback_responses,
            teammate_id: teammate.id,
            person_name: person_name_for(teammate),
            title: fr.subject_line.presence || "Feedback request ##{fr.id}",
            subtitle: "Response outstanding",
            url: routes.organization_feedback_request_path(organization, fr)
          )
        end
    end

    def ogo_comment_items
      return [] if teammate_ids.empty?

      person_ids = teammates.filter_map { |t| t.person_id }
      observee_observation_ids = Observee.where(teammate_id: teammate_ids).select(:observation_id)
      observer_observation_ids = Observation.where(company: organization, observer_id: person_ids).select(:id)

      Comment
        .root_comments
        .where(organization_id: organization.id, commentable_type: "Observation")
        .where("comments.created_at >= ?", OGO_COMMENT_LOOKBACK.ago)
        .where(
          "comments.commentable_id IN (?) OR comments.commentable_id IN (?)",
          observee_observation_ids,
          observer_observation_ids
        )
        .includes(:creator, :commentable)
        .order(created_at: :desc)
        .limit(200)
        .filter_map do |comment|
          observation = comment.commentable
          next unless observation.is_a?(Observation)

          teammate = teammate_for_observation(observation)
          Item.new(
            id: "ogo-comment-#{comment.id}",
            subtype_key: :ogo_comments,
            teammate_id: teammate&.id,
            person_name: teammate ? person_name_for(teammate) : (observation.observer&.display_name || "—"),
            title: comment.body.to_s.truncate(80),
            subtitle: "Comment on OGO · #{comment.created_at.to_date}",
            url: routes.organization_observation_path(organization, observation)
          )
        end
    end

    def teammate_for_observation(observation)
      observee_ids = observation.observees.map(&:teammate_id)
      teammates_by_id.values.find { |t| observee_ids.include?(t.id) } ||
        teammates_by_id.values.find { |t| t.person_id == observation.observer_id }
    end

    # --- Goals ---

    def goal_confidence_items
      return [] if teammate_ids.empty?

      week_cutoff = 1.week.ago.beginning_of_week(:monday)
      goals = Goal.active
        .check_in_eligible
        .where(owner_type: "CompanyTeammate", owner_id: teammate_ids)
        .includes(:goal_check_ins, :owner)

      goals.filter_map do |goal|
        teammate = teammates_by_id[goal.owner_id]
        next unless teammate

        last = goal.goal_check_ins.max_by(&:check_in_week_start)
        next if last && last.check_in_week_start >= week_cutoff

        Item.new(
          id: "goal-confidence-#{goal.id}",
          subtype_key: :goal_confidence,
          teammate_id: teammate.id,
          person_name: person_name_for(teammate),
          title: goal.title,
          subtitle: last ? "Last confidence week of #{last.check_in_week_start}" : "No confidence check-in yet",
          url: routes.organization_goal_path(organization, goal)
        )
      end
    end

    def wtm_missing_goal_items
      return [] if teammate_ids.empty?

      active_goal_keys = active_goal_association_keys
      items = []

      latest_assignment_wtm.each do |row|
        tid = row["teammate_id"].to_i
        assignment_id = row["assignment_id"].to_i
        next if active_goal_keys.include?(["Assignment", assignment_id, tid])

        teammate = teammates_by_id[tid]
        next unless teammate

        assignment = Assignment.find_by(id: assignment_id)
        next unless assignment

        items << Item.new(
          id: "wtm-assignment-#{tid}-#{assignment_id}",
          subtype_key: :wtm_missing_goals,
          teammate_id: tid,
          person_name: person_name_for(teammate),
          title: assignment.title,
          subtitle: "Working to meet · missing active goal",
          url: routes.choose_manage_goals_organization_assignment_path(
            organization,
            assignment,
            owner_id: "CompanyTeammate_#{tid}"
          )
        )
      end

      latest_aspiration_wtm.each do |row|
        tid = row["teammate_id"].to_i
        aspiration_id = row["aspiration_id"].to_i
        next if active_goal_keys.include?(["Aspiration", aspiration_id, tid])

        teammate = teammates_by_id[tid]
        next unless teammate

        aspiration = Aspiration.find_by(id: aspiration_id)
        next unless aspiration

        items << Item.new(
          id: "wtm-aspiration-#{tid}-#{aspiration_id}",
          subtype_key: :wtm_missing_goals,
          teammate_id: tid,
          person_name: person_name_for(teammate),
          title: aspiration.name,
          subtitle: "Working to meet value · missing active goal",
          url: routes.choose_manage_goals_organization_aspiration_path(
            organization,
            aspiration,
            owner_id: "CompanyTeammate_#{tid}"
          )
        )
      end

      items
    end

    def latest_assignment_wtm
      sql = ActiveRecord::Base.sanitize_sql_array([<<~SQL.squish, teammate_ids])
        SELECT teammate_id, assignment_id FROM (
          SELECT DISTINCT ON (teammate_id, assignment_id)
            teammate_id, assignment_id, official_rating
          FROM assignment_check_ins
          WHERE teammate_id IN (?)
            AND official_check_in_completed_at IS NOT NULL
          ORDER BY teammate_id, assignment_id, official_check_in_completed_at DESC, id DESC
        ) latest
        WHERE official_rating = 'working_to_meet'
      SQL
      ActiveRecord::Base.connection.exec_query(sql).to_a
    end

    def latest_aspiration_wtm
      sql = ActiveRecord::Base.sanitize_sql_array([<<~SQL.squish, teammate_ids])
        SELECT teammate_id, aspiration_id FROM (
          SELECT DISTINCT ON (teammate_id, aspiration_id)
            teammate_id, aspiration_id, official_rating
          FROM aspiration_check_ins
          WHERE teammate_id IN (?)
            AND official_check_in_completed_at IS NOT NULL
          ORDER BY teammate_id, aspiration_id, official_check_in_completed_at DESC, id DESC
        ) latest
        WHERE official_rating = 'working_to_meet'
      SQL
      ActiveRecord::Base.connection.exec_query(sql).to_a
    end

    def active_goal_association_keys
      return Set.new if teammate_ids.empty?

      rows = GoalAssociation
        .joins(:goal)
        .where(
          goals: {
            owner_type: "CompanyTeammate",
            owner_id: teammate_ids,
            completed_at: nil,
            deleted_at: nil
          }
        )
        .where.not(goals: { started_at: nil })
        .pluck(:associable_type, :associable_id, "goals.owner_id")

      Set.new(rows)
    end

    def milestone_gap_missing_goal_items
      return [] if teammate_ids.empty?

      statuses = EngagementHealthStatus.items
        .for_category(EngagementHealth::CATEGORY_MILESTONES)
        .where(organization: organization, teammate_id: teammate_ids)
        .where(status: [EngagementHealth::NEEDS_ATTENTION, EngagementHealth::WARNING])

      statuses.filter_map do |row|
        reason = row.inputs.is_a?(Hash) ? row.inputs["reason"] : nil
        next unless reason.in?(%w[no_milestone_and_no_goal draft_goal_attached])

        teammate = teammates_by_id[row.teammate_id]
        next unless teammate

        name = row.inputs.is_a?(Hash) ? row.inputs["name"] : nil
        ability = Ability.find_by(id: row.entity_id)
        title = name.presence || ability&.name || "Ability ##{row.entity_id}"

        Item.new(
          id: "milestone-gap-#{row.id}",
          subtype_key: :milestone_gap_missing_goals,
          teammate_id: teammate.id,
          person_name: person_name_for(teammate),
          title: title,
          subtitle: reason == "draft_goal_attached" ? "Milestone gap · draft goal only" : "Milestone gap · no active goal",
          url: if ability
                 routes.choose_manage_goals_organization_ability_path(
                   organization,
                   ability,
                   owner_id: "CompanyTeammate_#{teammate.id}"
                 )
               else
                 routes.organization_company_teammate_one_on_one_link_path(organization, teammate)
               end
        )
      end
    end

    # --- Expectation Alignment ---

    def maap_unresolved_comment_items
      Comment
        .root_comments
        .unresolved
        .without_position_suggestion
        .where(organization_id: organization.id, commentable_type: MAAP_COMMENT_TYPES)
        .includes(:creator, :commentable)
        .order(created_at: :desc)
        .limit(200)
        .map do |comment|
          commentable = comment.commentable
          Item.new(
            id: "maap-comment-#{comment.id}",
            subtype_key: :unresolved_maap_comments,
            teammate_id: nil,
            person_name: comment.creator&.display_name || "—",
            title: comment.body.to_s.truncate(80),
            subtitle: "#{commentable_type_label(commentable)} · unresolved",
            url: maap_commentable_url(commentable)
          )
        end
    end

    def commentable_type_label(commentable)
      case commentable
      when Assignment then "Assignment: #{commentable.title}"
      when Position then "Position: #{commentable.display_name}"
      when Ability then "Ability: #{commentable.name}"
      else commentable.class.name
      end
    end

    def maap_commentable_url(commentable)
      case commentable
      when Assignment
        routes.organization_assignment_path(organization, commentable)
      when Position
        routes.organization_position_path(organization, commentable)
      when Ability
        routes.organization_ability_path(organization, commentable)
      else
        routes.organization_path(organization)
      end
    end

    def person_name_for(teammate)
      teammate.person&.display_name || teammate.to_s
    end
  end
end
