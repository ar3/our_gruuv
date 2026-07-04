# frozen_string_literal: true

module EngagementHealth
  # Computes every engagement-health row (item-level and category rollups)
  # for one teammate. Both the event-driven path and the daily scheduled job
  # go through this class, so there is exactly one definition of the rules.
  #
  # Returns an array of row hashes:
  #   { level:, category:, entity_type:, entity_id:, status:, inputs: {} }
  class Calculator
    def self.call(teammate:, organization: nil, reference_time: Time.current)
      new(teammate: teammate, organization: organization, reference_time: reference_time).call
    end

    def initialize(teammate:, organization: nil, reference_time: Time.current)
      @teammate = teammate
      @organization = organization || teammate.organization
      @reference_time = reference_time
    end

    def call
      rows = []
      rows.concat(ogo_rows(CATEGORY_OGO_GIVEN, last_ogo_given, "OGOs given"))
      rows.concat(ogo_rows(CATEGORY_OGO_RECEIVED, last_ogo_received, "OGOs received"))
      rows.concat(goal_confidence_rows)
      rows.concat(required_clarity_rows)
      rows.concat(milestone_rows)
      rows
    end

    private

    attr_reader :teammate, :organization, :reference_time

    # --- OGO given / received (single signal: item and category match) ---

    def last_ogo_given
      last_observation_before(
        Observations::HealthScopes.given_scope(teammate, organization),
        :published_at
      )
    end

    def last_ogo_received
      last_observation_before(
        Observations::HealthScopes.received_scope(teammate, organization),
        :published_at
      )
    end

    def ogo_rows(category, last_observation, signal_name)
      last_published_at = last_observation&.published_at
      status = Thresholds.status_for_last_event(
        last_published_at,
        healthy_within: Thresholds::OGO_HEALTHY_WITHIN_DAYS,
        needs_attention_at: Thresholds::OGO_NEEDS_ATTENTION_AT_DAYS,
        reference_time: reference_time
      )
      inputs = {
        "name" => signal_name,
        "last_event_at" => last_published_at&.iso8601,
        "days_since_last_event" => Thresholds.days_since(last_published_at, reference_time: reference_time),
        "never" => last_published_at.nil?,
        "healthy_within_days" => Thresholds::OGO_HEALTHY_WITHIN_DAYS,
        "needs_attention_at_days" => Thresholds::OGO_NEEDS_ATTENTION_AT_DAYS
      }
      if last_observation
        inputs["last_event_type"] = "Observation"
        inputs["last_event_id"] = last_observation.id
        inputs["last_event_summary"] = last_observation.story.to_s.truncate(80)
      end
      item = item_row(category, nil, nil, status, inputs)
      [item, rollup_row(category, [item])]
    end

    # --- Goal confidence ---

    def goal_confidence_rows
      goals = goal_confidence_goals
      items = goals.map do |goal|
        last_check_in = goal.goal_check_ins
          .select { |check_in| check_in.updated_at <= reference_time }
          .max_by(&:updated_at)
        last_check_in_at = last_check_in&.updated_at
        status = Thresholds.status_for_last_event(
          last_check_in_at,
          healthy_within: Thresholds::GOAL_CONFIDENCE_HEALTHY_WITHIN_DAYS,
          needs_attention_at: Thresholds::GOAL_CONFIDENCE_NEEDS_ATTENTION_AT_DAYS,
          reference_time: reference_time
        )
        inputs = {
          "name" => goal.title,
          "goal_state" => goal_state_at_reference_time(goal),
          "completed_at" => goal.completed_at&.iso8601,
          "last_event_at" => last_check_in_at&.iso8601,
          "days_since_last_event" => Thresholds.days_since(last_check_in_at, reference_time: reference_time),
          "never" => last_check_in_at.nil?,
          "healthy_within_days" => Thresholds::GOAL_CONFIDENCE_HEALTHY_WITHIN_DAYS,
          "needs_attention_at_days" => Thresholds::GOAL_CONFIDENCE_NEEDS_ATTENTION_AT_DAYS
        }
        if last_check_in
          inputs["last_event_type"] = "GoalCheckIn"
          inputs["last_event_id"] = last_check_in.id
          inputs["last_event_summary"] = goal_check_in_summary(last_check_in)
        end
        item_row(CATEGORY_GOAL_CONFIDENCE, "Goal", goal.id, status, inputs)
      end

      if items.empty?
        # Never started or completed a goal is itself the failure signal.
        rollup = rollup_row(CATEGORY_GOAL_CONFIDENCE, [])
        rollup[:status] = NEEDS_ATTENTION
        rollup[:inputs]["empty_reason"] = "never_started_or_completed_a_goal"
        return [rollup]
      end

      items + [rollup_row(CATEGORY_GOAL_CONFIDENCE, items)]
    end

    # Items: active goals (started, not completed) plus goals completed within
    # the window; completed goals then drop out. Drafts are not items.
    def goal_confidence_goals
      window_start = reference_time - Thresholds::COMPLETED_GOAL_WINDOW_DAYS.days
      Goal.unscoped
        .where(owner_type: "CompanyTeammate", owner_id: teammate.id)
        .where("goals.created_at <= ?", reference_time)
        .where("goals.deleted_at IS NULL OR goals.deleted_at > ?", reference_time)
        .where(
          "(started_at IS NOT NULL AND started_at <= ? AND (completed_at IS NULL OR completed_at > ?)) " \
          "OR (completed_at >= ? AND completed_at <= ?)",
          reference_time, reference_time, window_start, reference_time
        )
        .includes(:goal_check_ins)
        .order(:created_at)
    end

    # --- Required clarity check-ins ---
    # Item set matches required_check_ins at reference_time: position from the
    # employment tenure active then, assignments from that position plus active
    # assignment tenures, and aspirations that existed in the org.

    def required_clarity_rows
      items = required_position_items + required_assignment_items + required_aspiration_items

      if items.empty?
        rollup = rollup_row(CATEGORY_REQUIRED_CLARITY, [])
        rollup[:inputs]["empty_reason"] = "no_required_items_vacuously_healthy"
        return [rollup]
      end

      items + [rollup_row(CATEGORY_REQUIRED_CLARITY, items)]
    end

    def required_position_items
      position = position_at_reference_time
      return [] unless position

      latest = latest_closed_check_in(
        PositionCheckIn.where(company_teammate: teammate)
      )
      open_ci = open_check_in_at_reference(
        PositionCheckIn.where(company_teammate: teammate)
      )
      [clarity_item("Position", position.id, position.display_name, latest, open_check_in: open_ci)]
    end

    def required_assignment_items
      position = position_at_reference_time
      required_position_assignment_ids = position ? position.required_assignments.pluck(:assignment_id) : []
      assignment_ids = (required_position_assignment_ids + assignment_tenure_assignment_ids_at_reference_time).uniq
      return [] if assignment_ids.empty?

      assignments_by_id = Assignment.where(id: assignment_ids).index_by(&:id)
      latest_by_assignment_id = AssignmentCheckIn
        .where(company_teammate: teammate, assignment_id: assignment_ids)
        .closed
        .where("official_check_in_completed_at <= ?", reference_time)
        .order(official_check_in_completed_at: :desc)
        .group_by(&:assignment_id)
        .transform_values(&:first)

      open_by_assignment_id = AssignmentCheckIn
        .where(company_teammate: teammate, assignment_id: assignment_ids)
        .order(assignment_id: :asc, created_at: :desc)
        .group_by(&:assignment_id)
        .transform_values { |check_ins| open_check_in_at_reference(check_ins) }

      assignment_ids.filter_map do |assignment_id|
        assignment = assignments_by_id[assignment_id]
        next unless assignment

        latest = latest_by_assignment_id[assignment_id]
        clarity_item(
          "Assignment",
          assignment.id,
          assignment.title,
          latest,
          open_check_in: open_by_assignment_id[assignment_id]
        )
      end
    end

    def required_aspiration_items
      aspirations = ReferenceTime.aspirations_for(organization: organization, reference_time: reference_time).to_a
      return [] if aspirations.empty?

      latest_by_aspiration_id = AspirationCheckIn
        .where(company_teammate: teammate, aspiration_id: aspirations.map(&:id))
        .closed
        .where("official_check_in_completed_at <= ?", reference_time)
        .order(official_check_in_completed_at: :desc)
        .group_by(&:aspiration_id)
        .transform_values(&:first)

      open_by_aspiration_id = AspirationCheckIn
        .where(company_teammate: teammate, aspiration_id: aspirations.map(&:id))
        .order(aspiration_id: :asc, created_at: :desc)
        .group_by(&:aspiration_id)
        .transform_values { |check_ins| open_check_in_at_reference(check_ins) }

      aspirations.map do |aspiration|
        latest = latest_by_aspiration_id[aspiration.id]
        clarity_item(
          "Aspiration",
          aspiration.id,
          aspiration.name,
          latest,
          open_check_in: open_by_aspiration_id[aspiration.id]
        )
      end
    end

    def clarity_item(entity_type, entity_id, name, last_check_in, open_check_in: nil)
      last_finalized_at = last_check_in&.official_check_in_completed_at
      days_since = Thresholds.days_since(last_finalized_at, reference_time: reference_time)
      status = Thresholds.status_for_last_event(
        last_finalized_at,
        healthy_within: Thresholds::REQUIRED_CLARITY_HEALTHY_WITHIN_DAYS,
        needs_attention_at: Thresholds::REQUIRED_CLARITY_NEEDS_ATTENTION_AT_DAYS,
        reference_time: reference_time
      )
      inputs = {
        "name" => name,
        "last_event_at" => last_finalized_at&.iso8601,
        "days_since_last_event" => days_since,
        "never" => last_finalized_at.nil?,
        "healthy_within_days" => Thresholds::REQUIRED_CLARITY_HEALTHY_WITHIN_DAYS,
        "needs_attention_at_days" => Thresholds::REQUIRED_CLARITY_NEEDS_ATTENTION_AT_DAYS
      }
      if last_check_in
        inputs["last_event_type"] = last_check_in.class.name
        inputs["last_event_id"] = last_check_in.id
        inputs["last_event_summary"] = "Finalized #{name} check-in"
      end
      inputs.merge!(
        WorkflowSnapshot.call(
          status: status,
          open_check_in: open_check_in,
          last_closed_check_in: last_check_in,
          reference_time: reference_time,
          days_since_last_event: days_since
        )
      )
      item_row(CATEGORY_REQUIRED_CLARITY, entity_type, entity_id, status, inputs)
    end

    def latest_closed_check_in(scope)
      scope
        .where.not(official_check_in_completed_at: nil)
        .where("official_check_in_completed_at <= ?", reference_time)
        .order(official_check_in_completed_at: :desc)
        .first
    end

    def open_check_in_at_reference(check_ins)
      Array(check_ins)
        .select { |check_in| check_in.created_at <= reference_time }
        .find { |check_in| check_in.official_check_in_completed_at.nil? || check_in.official_check_in_completed_at > reference_time }
    end

    # --- Milestones ---
    # Items: abilities required by the position and assignment tenures active at
    # reference_time. Earned milestones and attached goals are also evaluated as
    # of reference_time.

    def milestone_rows
      required_levels = milestone_required_levels

      if required_levels.empty?
        rollup = rollup_row(CATEGORY_MILESTONES, [])
        rollup[:inputs]["empty_reason"] = "no_required_abilities_vacuously_healthy"
        return [rollup]
      end

      abilities_by_id = Ability.where(id: required_levels.keys).index_by(&:id)
      earned_levels = TeammateMilestone
        .where(company_teammate: teammate, ability_id: required_levels.keys)
        .where("attained_at <= ?", reference_time)
        .group(:ability_id)
        .maximum(:milestone_level)
      goal_counts = ability_goal_counts(required_levels.keys)

      items = required_levels.filter_map do |ability_id, required_level|
        ability = abilities_by_id[ability_id]
        next unless ability

        earned_level = earned_levels[ability_id].to_i
        counts = goal_counts.fetch(ability_id, { active: 0, draft: 0 })
        status, reason = milestone_status(required_level, earned_level, counts)
        inputs = {
          "name" => ability.name,
          "required_level" => required_level,
          "earned_level" => earned_level,
          "active_goal_count" => counts[:active],
          "draft_goal_count" => counts[:draft],
          "reason" => reason
        }
        item_row(CATEGORY_MILESTONES, "Ability", ability_id, status, inputs)
      end

      items + [rollup_row(CATEGORY_MILESTONES, items)]
    end

    def milestone_status(required_level, earned_level, goal_counts)
      return [HEALTHY, "earned_required_milestone"] if earned_level >= required_level
      return [HEALTHY, "active_goal_attached"] if goal_counts[:active].positive?
      return [AT_RISK, "earlier_milestone_earned"] if earned_level.positive?
      return [AT_RISK, "draft_goal_attached"] if goal_counts[:draft].positive?

      [NEEDS_ATTENTION, "no_milestone_and_no_goal"]
    end

    def milestone_required_levels
      required_levels = Hash.new(0)
      position = position_at_reference_time

      if position
        position.position_abilities.each do |position_ability|
          ability_id = position_ability.ability_id
          required_levels[ability_id] = [required_levels[ability_id], position_ability.milestone_level.to_i].max
        end
        position.required_assignments.includes(assignment: :assignment_abilities).each do |position_assignment|
          position_assignment.assignment&.assignment_abilities&.each do |assignment_ability|
            ability_id = assignment_ability.ability_id
            required_levels[ability_id] = [required_levels[ability_id], assignment_ability.milestone_level.to_i].max
          end
        end
      end

      assignment_tenures_at_reference_time.includes(assignment: :assignment_abilities).each do |tenure|
        tenure.assignment.assignment_abilities.each do |assignment_ability|
          ability_id = assignment_ability.ability_id
          required_levels[ability_id] = [required_levels[ability_id], assignment_ability.milestone_level.to_i].max
        end
      end

      required_levels
    end

    # Only goals owned by this teammate count as attached; completed and
    # soft-deleted goals never count.
    def ability_goal_counts(ability_ids)
      rows = Goal.unscoped.joins(:goal_associations)
        .where(owner_type: "CompanyTeammate", owner_id: teammate.id)
        .where(goal_associations: { associable_type: "Ability", associable_id: ability_ids })
        .where("goals.created_at <= ?", reference_time)
        .where("goals.deleted_at IS NULL OR goals.deleted_at > ?", reference_time)
        .where("goals.completed_at IS NULL OR goals.completed_at > ?", reference_time)
        .pluck("goal_associations.associable_id", :started_at)

      rows.each_with_object({}) do |(ability_id, started_at), counts|
        counts[ability_id] ||= { active: 0, draft: 0 }
        if started_at.present? && started_at <= reference_time
          counts[ability_id][:active] += 1
        else
          counts[ability_id][:draft] += 1
        end
      end
    end

    # --- Shared helpers ---

    def last_observation_before(scope, timestamp_column)
      scope
        .where(scope.arel_table[timestamp_column].lteq(reference_time))
        .order(timestamp_column => :desc)
        .first
    end

    def goal_check_in_summary(check_in)
      summary = "Confidence check: #{check_in.confidence_percentage}%"
      reason = check_in.confidence_reason.to_s.strip
      reason.present? ? "#{summary} — #{reason.truncate(60)}" : summary
    end

    def goal_state_at_reference_time(goal)
      if goal.completed_at.present? && goal.completed_at <= reference_time
        "completed"
      else
        "active"
      end
    end

    def position_at_reference_time
      return @position_at_reference_time if defined?(@position_at_reference_time)

      @position_at_reference_time = ReferenceTime.employment_tenure_for(
        teammate: teammate,
        organization: organization,
        reference_time: reference_time
      )&.position
    end

    def assignment_tenures_at_reference_time
      return @assignment_tenures_at_reference_time if defined?(@assignment_tenures_at_reference_time)

      @assignment_tenures_at_reference_time = ReferenceTime.assignment_tenures_for(
        teammate: teammate,
        organization: organization,
        reference_time: reference_time
      )
    end

    def assignment_tenure_assignment_ids_at_reference_time
      assignment_tenures_at_reference_time.distinct.pluck(:assignment_id)
    end

    def item_row(category, entity_type, entity_id, status, inputs)
      {
        level: "item",
        category: category,
        entity_type: entity_type,
        entity_id: entity_id,
        status: status,
        inputs: inputs
      }
    end

    # Worst status wins; the rollup records which items were the "worst" so
    # the debug page can show exactly what produced each category rating.
    def rollup_row(category, items)
      status = EngagementHealth.worst_status(items.map { |item| item[:status] })
      determining = items.select { |item| item[:status] == status }
      {
        level: "category",
        category: category,
        entity_type: nil,
        entity_id: nil,
        status: status,
        inputs: {
          "item_count" => items.size,
          "determined_by" => determining.map do |item|
            {
              "entity_type" => item[:entity_type],
              "entity_id" => item[:entity_id],
              "name" => item[:inputs]["name"]
            }
          end
        }
      }
    end
  end
end
