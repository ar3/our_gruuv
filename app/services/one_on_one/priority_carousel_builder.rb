# frozen_string_literal: true
require "set"

module OneOnOne
  class PriorityCarouselBuilder
    ASANA_URGENT_TASKS_TITLE = "Are there overdue or due-soon Asana tasks?".freeze
    REMAINING_ASANA_TASKS_TITLE = "Are there incomplete tasks remaining in the linked Asana project?".freeze

    def self.call(...) = new(...).call

    def initialize(organization:, teammate:, one_on_one_link:)
      @organization = organization
      @teammate = teammate
      @one_on_one_link = one_on_one_link
      @today = Date.current
      @week_start = Date.current.beginning_of_week(:monday)
      @thirty_days_ago = 30.days.ago
      @active_goal_lookup = build_active_goal_lookup
    end

    def call
      priorities = build_priorities
      needs_attention_count = priorities.count { |row| row[:needs_attention] && !row[:not_applicable] }
      first_attention_index = priorities.index { |row| row[:needs_attention] } || 0

      {
        priorities: priorities,
        needs_attention_count: needs_attention_count,
        total_count: priorities.count,
        first_attention_index: first_attention_index
      }
    end

    private

    def build_priorities
      [
        priority_asana_urgent_tasks,
        priority_blurred_or_obscured_check_ins,
        priority_wtm_required_or_active_without_goals,
        priority_current_position_milestone_gaps_without_goals,
        priority_no_observation_given_30d,
        priority_no_observation_received_30d,
        priority_no_wtm_observation_received_30d,
        priority_active_goals_without_check_in_this_week,
        priority_no_active_goals,
        priority_remaining_asana_tasks,
        priority_target_unique_required_assignments_without_goals,
        priority_target_unique_milestone_gaps_without_goals
      ].each_with_index.map do |row, idx|
        row.merge(position: idx + 1, total: 12)
      end
    end

    def teammate_casual_name
      @teammate.person.casual_name
    end

    def current_position_title
      @teammate.active_employment_tenure&.position&.display_name.presence || "current position"
    end

    def target_position_title
      @teammate.next_goal_position&.display_name.presence || "undefined target position"
    end

    def priority_asana_urgent_tasks
      cache = asana_cache
      return not_applicable_priority(ASANA_URGENT_TASKS_TITLE) unless asana_source?

      if cache.blank?
        return attention_priority(
          ASANA_URGENT_TASKS_TITLE,
          "Asana is linked but project data is not synced yet.",
          ["Sync the Asana project first to evaluate urgent tasks."],
          cta_kind: :sync_anchor,
          cta_label: "Sync Asana now"
        )
      end

      tasks = cache.incomplete_items.select do |item|
        due_on = parse_due_on(item["due_on"])
        due_on && due_on <= (@today + 7.days)
      end
      tasks = tasks.sort_by { |item| [parse_due_on(item["due_on"]) || Date.new(9999, 12, 31), (item["name"] || "").downcase] }

      if tasks.any?
        attention_priority(
          ASANA_URGENT_TASKS_TITLE,
          "There are tasks overdue or due in the next week.",
          tasks.map { |item| format_task_link_item(item) },
          cta_kind: :sync_anchor,
          cta_label: "Open urgent Asana tasks"
        )
      else
        success_priority(
          ASANA_URGENT_TASKS_TITLE,
          "No incomplete Asana tasks are overdue or due in the next week.",
          ["Everything urgent in Asana is already under control."]
        )
      end
    end

    def priority_blurred_or_obscured_check_ins
      rows = []

      position = @teammate.active_employment_tenure&.position
      pos_check_in = PositionCheckIn.latest_finalized_for(@teammate)
      pos_clarity = pos_check_in&.clarity_level || :obscured
      if %i[blurred obscured].include?(pos_clarity)
        rows << {
          label: "Position: #{position&.display_name || 'Current position'} (#{pos_clarity.to_s.humanize.downcase})",
          finalized_at: pos_check_in&.official_check_in_completed_at
        }
      end

      assignment_ids = []
      assignment_ids.concat(position&.required_assignments&.pluck(:assignment_id) || [])
      assignment_ids.concat(@teammate.assignment_tenures.active.pluck(:assignment_id))
      assignment_ids.uniq.each do |assignment_id|
        assignment = Assignment.find_by(id: assignment_id)
        next if assignment.blank?

        latest = AssignmentCheckIn.latest_finalized_for(@teammate, assignment)
        clarity = latest&.clarity_level || :obscured
        next unless %i[blurred obscured].include?(clarity)

        rows << {
          label: "Assignment: #{assignment.title} (#{clarity.to_s.humanize.downcase})",
          finalized_at: latest&.official_check_in_completed_at
        }
      end

      Aspiration.within_hierarchy(@organization).find_each do |aspiration|
        latest = AspirationCheckIn.latest_finalized_for(@teammate, aspiration)
        clarity = latest&.clarity_level || :obscured
        next unless %i[blurred obscured].include?(clarity)

        rows << {
          label: "Aspiration: #{aspiration.name} (#{clarity.to_s.humanize.downcase})",
          finalized_at: latest&.official_check_in_completed_at
        }
      end

      rows.sort_by! { |row| [row[:finalized_at] || Time.at(0), row[:label].downcase] }

      title = "Are any position, assignment, or aspiration check-ins blurred or obscured?"
      if rows.any?
        attention_priority(
          title,
          "At least one required check-in is blurred or obscured.",
          rows.map { |row| row[:label] },
          cta_kind: :check_ins_page,
          cta_label: "Open teammate check-ins"
        )
      else
        success_priority(
          title,
          "Required check-ins are clear or crystal clear.",
          ["No blurred or obscured assignment, aspiration, or position check-ins were found."]
        )
      end
    end

    def priority_wtm_required_or_active_without_goals
      latest_assignment_check_ins = AssignmentCheckIn.where(company_teammate: @teammate).closed.order(official_check_in_completed_at: :desc).index_by(&:assignment_id)
      latest_aspiration_check_ins = AspirationCheckIn.where(company_teammate: @teammate).closed.order(official_check_in_completed_at: :desc).index_by(&:aspiration_id)

      position = @teammate.active_employment_tenure&.position
      assignment_ids = []
      assignment_ids.concat(position&.required_assignments&.pluck(:assignment_id) || [])
      assignment_ids.concat(@teammate.assignment_tenures.active.pluck(:assignment_id))
      assignment_ids.uniq!

      rows = []
      assignment_ids.each do |assignment_id|
        check_in = latest_assignment_check_ins[assignment_id]
        next unless check_in&.official_rating == "working_to_meet"
        next if @active_goal_lookup[["Assignment", assignment_id]]

        assignment = Assignment.find_by(id: assignment_id)
        rows << { label: "Assignment: #{assignment&.title || "Assignment ##{assignment_id}"}", associable: assignment }
      end

      latest_aspiration_check_ins.values.each do |check_in|
        next unless check_in.official_rating == "working_to_meet"
        next if @active_goal_lookup[["Aspiration", check_in.aspiration_id]]

        aspiration = Aspiration.find_by(id: check_in.aspiration_id)
        rows << { label: "Aspiration: #{aspiration&.name || "Aspiration ##{check_in.aspiration_id}"}", associable: aspiration }
      end

      rows.sort_by! { |row| row[:label].downcase }

      title = "Are any working-to-meet assignments or aspirational values missing active goals?"
      if rows.any?
        first = rows.first[:associable]
        attention_priority(
          title,
          "Working-to-meet areas exist without active goals.",
          rows.map { |row| row[:label] },
          cta_kind: first.present? ? :associable_goals : :bulk_goals,
          cta_label: first.present? ? "Create goal for top item" : "Create goals in bulk",
          cta_associable: first
        )
      else
        success_priority(
          title,
          "Working-to-meet assignment/aspiration gaps already have active goals.",
          ["No uncovered WTM assignment or aspiration gaps were found."]
        )
      end
    end

    def priority_current_position_milestone_gaps_without_goals
      rows = current_position_ability_gaps_without_goals
      title = "Are any #{current_position_title} ability milestones below target missing active goals?"
      if rows.any?
        first = rows.first[:ability]
        attention_priority(
          title,
          "Current-position ability milestone gaps exist without active goals.",
          rows.map { |row| "Ability: #{row[:ability].name} (need M#{row[:required_level]}, earned M#{row[:earned_level]})" },
          cta_kind: first.present? ? :associable_goals : :bulk_goals,
          cta_label: first.present? ? "Create goal for top ability" : "Create goals in bulk",
          cta_associable: first
        )
      else
        success_priority(
          title,
          "Current-position ability gaps are already covered by active goals.",
          ["No uncovered current-position ability milestone gaps were found."]
        )
      end
    end

    def priority_no_observation_given_30d
      given_count = Observation
        .where(company: @organization, observer: @teammate.person, deleted_at: nil)
        .published
        .not_journal
        .where("observed_at >= ?", @thirty_days_ago)
        .joins(:observees)
        .where.not(observees: { teammate_id: @teammate.id })
        .distinct
        .count

      title = "Has #{teammate_casual_name} given a published observation to someone else in the last 30 days?"
      if given_count.zero?
        attention_priority(
          title,
          "No published non-journal observation was given to someone else in the last 30 days.",
          ["Give one concrete observation to support someone else this week."],
          cta_kind: :new_observation,
          cta_label: "Start an observation"
        )
      else
        success_priority(
          title,
          "Published non-journal observations were given in the last 30 days.",
          ["Great momentum: #{given_count} published observation(s) given in the last 30 days."]
        )
      end
    end

    def priority_no_observation_received_30d
      recent_received = recent_received_non_journal_observations
      title = "Has #{teammate_casual_name} received a published observation in the last 30 days?"
      if recent_received.empty?
        attention_priority(
          title,
          "No published non-journal observation was received in the last 30 days.",
          ["Request fresh feedback to keep clarity high."],
          cta_kind: :new_feedback_request,
          cta_label: "Create feedback request"
        )
      else
        labels = recent_received.first(3).map { |obs| "From #{obs.observer.display_name} on #{obs.observed_at.to_date.strftime('%b %d')}" }
        success_priority(
          title,
          "Published non-journal observations were received in the last 30 days.",
          labels
        )
      end
    end

    def priority_no_wtm_observation_received_30d
      rows = wtm_items_without_received_observations
      title = "Have all working-to-meet assignments and aspirational values received an observation in the last 30 days?"
      if rows.any?
        attention_priority(
          title,
          "At least one working-to-meet assignment/aspiration has no published non-journal observation in the last 30 days.",
          rows.map { |row| row[:label] },
          cta_kind: :new_feedback_request,
          cta_label: "Create feedback request"
        )
      else
        success_priority(
          title,
          "Working-to-meet assignment/aspiration areas have recent published observations.",
          ["No WTM assignment/aspiration is missing received observation coverage in the last 30 days."]
        )
      end
    end

    def priority_active_goals_without_check_in_this_week
      active_goals = Goal.active.where(owner: @teammate, deleted_at: nil).includes(:goal_check_ins).to_a
      stale = active_goals.select do |goal|
        latest = goal.goal_check_ins.max_by(&:check_in_week_start)
        latest.nil? || latest.check_in_week_start < @week_start
      end
      stale.sort_by!(&:title)

      title = "Do all active goals have a check-in for this week?"
      if stale.any?
        attention_priority(
          title,
          "At least one active goal does not have a check-in for this week.",
          stale.map { |goal| goal.title },
          cta_kind: :goals_index,
          cta_label: "Open goals check-ins"
        )
      else
        success_priority(
          title,
          "All active goals already have a check-in this week.",
          ["All active goals are up to date for the current week."]
        )
      end
    end

    def priority_remaining_asana_tasks
      cache = asana_cache
      return not_applicable_priority(REMAINING_ASANA_TASKS_TITLE) unless asana_source?

      if cache.blank?
        return attention_priority(
          REMAINING_ASANA_TASKS_TITLE,
          "Asana is linked but project data is not synced yet.",
          ["Sync the Asana project first to evaluate remaining tasks."],
          cta_kind: :sync_anchor,
          cta_label: "Sync Asana now"
        )
      end

      remaining = cache.incomplete_items.sort_by { |item| [(item["name"] || "").downcase] }
      if remaining.any?
        attention_priority(
          REMAINING_ASANA_TASKS_TITLE,
          "There are still incomplete tasks in the linked Asana project.",
          remaining.map { |item| format_task_link_item(item) },
          cta_kind: :sync_anchor,
          cta_label: "Open remaining tasks"
        )
      else
        success_priority(
          REMAINING_ASANA_TASKS_TITLE,
          "No incomplete tasks remain in the linked Asana project.",
          ["Nice work: the linked Asana task list is clear."]
        )
      end
    end

    def priority_no_active_goals
      active_goal_count = Goal.active.where(owner: @teammate, deleted_at: nil).count
      title = "Does #{teammate_casual_name} have at least one active goal?"
      if active_goal_count.zero?
        attention_priority(
          title,
          "The teammate currently has no active goals.",
          ["Start at least one active goal to keep growth moving."],
          cta_kind: :bulk_goals,
          cta_label: "Create goals"
        )
      else
        success_priority(
          title,
          "There is at least one active goal in progress.",
          ["#{active_goal_count} active goal(s) are currently in motion."]
        )
      end
    end

    def priority_target_unique_required_assignments_without_goals
      rows = target_unique_required_assignment_rows
      title = "Are required assignments unique to #{target_position_title} still missing active goals?"
      if rows.any?
        first = rows.first[:assignment]
        attention_priority(
          title,
          "Target-position required assignments unique to that position have no active goals.",
          rows.map { |row| "Assignment: #{row[:assignment].title}" },
          cta_kind: first.present? ? :associable_goals : :bulk_goals,
          cta_label: first.present? ? "Create goal for top assignment" : "Create goals in bulk",
          cta_associable: first
        )
      else
        success_priority(
          title,
          "Target-position unique required assignments are already covered by active goals.",
          ["No uncovered target-only required assignments were found."]
        )
      end
    end

    def priority_target_unique_milestone_gaps_without_goals
      rows = target_unique_ability_gap_rows
      title = "Are ability milestones unique to #{target_position_title} below target still missing active goals?"
      if rows.any?
        first = rows.first[:ability]
        attention_priority(
          title,
          "Target-position unique ability milestone gaps exist without active goals.",
          rows.map { |row| "Ability: #{row[:ability].name} (need M#{row[:required_level]}, earned M#{row[:earned_level]})" },
          cta_kind: first.present? ? :associable_goals : :bulk_goals,
          cta_label: first.present? ? "Create goal for top ability" : "Create goals in bulk",
          cta_associable: first
        )
      else
        success_priority(
          title,
          "Target-position unique ability milestone gaps are already covered by active goals.",
          ["No uncovered target-only ability milestone gaps were found."]
        )
      end
    end

    def current_position_ability_gaps_without_goals
      position = @teammate.active_employment_tenure&.position
      return [] unless position

      current_map = MyGrowthAbilityMilestoneRows.structured_requirements_by_ability_id(position)
      return [] if current_map.empty?

      ability_ids = current_map.keys
      abilities = Ability.where(id: ability_ids).index_by(&:id)
      earned_levels = TeammateMilestone.where(company_teammate: @teammate, ability_id: ability_ids).group(:ability_id).maximum(:milestone_level)

      ability_ids.each_with_object([]) do |ability_id, memo|
        required_level = current_map[ability_id][:minimum_milestone_level].to_i
        earned_level = earned_levels[ability_id].to_i
        next unless required_level > earned_level
        next if @active_goal_lookup[["Ability", ability_id]]

        ability = abilities[ability_id]
        next if ability.blank?
        memo << { ability: ability, required_level: required_level, earned_level: earned_level }
      end.sort_by { |row| row[:ability].name.downcase }
    end

    def target_unique_required_assignment_rows
      current_position = @teammate.active_employment_tenure&.position
      target_position = @teammate.next_goal_position
      return [] unless target_position

      current_required = current_position&.required_assignments&.pluck(:assignment_id)&.to_set || Set.new
      target_required_ids = target_position.required_assignments.pluck(:assignment_id)
      unique_target_ids = target_required_ids.reject { |id| current_required.include?(id) }

      assignments = Assignment.where(id: unique_target_ids).index_by(&:id)
      unique_target_ids.each_with_object([]) do |assignment_id, memo|
        next if @active_goal_lookup[["Assignment", assignment_id]]
        assignment = assignments[assignment_id]
        next unless assignment
        memo << { assignment: assignment }
      end.sort_by { |row| row[:assignment].title.downcase }
    end

    def target_unique_ability_gap_rows
      current_position = @teammate.active_employment_tenure&.position
      target_position = @teammate.next_goal_position
      return [] unless target_position

      current_map = MyGrowthAbilityMilestoneRows.structured_requirements_by_ability_id(current_position)
      target_map = MyGrowthAbilityMilestoneRows.structured_requirements_by_ability_id(target_position)
      return [] if target_map.empty?

      target_unique_ids = target_map.keys.select do |ability_id|
        target_req = target_map[ability_id][:minimum_milestone_level].to_i
        current_req = current_map[ability_id]&.dig(:minimum_milestone_level).to_i
        target_req > current_req
      end
      return [] if target_unique_ids.empty?

      abilities = Ability.where(id: target_unique_ids).index_by(&:id)
      earned_levels = TeammateMilestone.where(company_teammate: @teammate, ability_id: target_unique_ids).group(:ability_id).maximum(:milestone_level)

      target_unique_ids.each_with_object([]) do |ability_id, memo|
        required_level = target_map[ability_id][:minimum_milestone_level].to_i
        earned_level = earned_levels[ability_id].to_i
        next unless required_level > earned_level
        next if @active_goal_lookup[["Ability", ability_id]]

        ability = abilities[ability_id]
        next unless ability
        memo << { ability: ability, required_level: required_level, earned_level: earned_level }
      end.sort_by { |row| row[:ability].name.downcase }
    end

    def wtm_items_without_received_observations
      latest_assignment_check_ins = AssignmentCheckIn.where(company_teammate: @teammate).closed.order(official_check_in_completed_at: :desc).index_by(&:assignment_id)
      latest_aspiration_check_ins = AspirationCheckIn.where(company_teammate: @teammate).closed.order(official_check_in_completed_at: :desc).index_by(&:aspiration_id)

      recent_assignment_ids = Observation.joins(:observees, :observation_ratings)
        .where(company: @organization, deleted_at: nil)
        .published
        .not_journal
        .where("observed_at >= ?", @thirty_days_ago)
        .where(observees: { teammate_id: @teammate.id })
        .where(observation_ratings: { rateable_type: "Assignment" })
        .distinct
        .pluck("observation_ratings.rateable_id")
        .to_set

      recent_aspiration_ids = Observation.joins(:observees, :observation_ratings)
        .where(company: @organization, deleted_at: nil)
        .published
        .not_journal
        .where("observed_at >= ?", @thirty_days_ago)
        .where(observees: { teammate_id: @teammate.id })
        .where(observation_ratings: { rateable_type: "Aspiration" })
        .distinct
        .pluck("observation_ratings.rateable_id")
        .to_set

      rows = []
      latest_assignment_check_ins.each_value do |check_in|
        next unless check_in.official_rating == "working_to_meet"
        next if recent_assignment_ids.include?(check_in.assignment_id)
        assignment = Assignment.find_by(id: check_in.assignment_id)
        rows << { label: "Assignment: #{assignment&.title || "Assignment ##{check_in.assignment_id}"}" }
      end

      latest_aspiration_check_ins.each_value do |check_in|
        next unless check_in.official_rating == "working_to_meet"
        next if recent_aspiration_ids.include?(check_in.aspiration_id)
        aspiration = Aspiration.find_by(id: check_in.aspiration_id)
        rows << { label: "Aspiration: #{aspiration&.name || "Aspiration ##{check_in.aspiration_id}"}" }
      end

      rows.sort_by { |row| row[:label].downcase }
    end

    def recent_received_non_journal_observations
      Observation.joins(:observees)
        .where(company: @organization, deleted_at: nil)
        .published
        .not_journal
        .where("observed_at >= ?", @thirty_days_ago)
        .where(observees: { teammate_id: @teammate.id })
        .includes(:observer)
        .order(observed_at: :desc)
        .distinct
        .to_a
    end

    def build_active_goal_lookup
      GoalAssociation
        .joins(:goal)
        .where(goals: { owner_type: "CompanyTeammate", owner_id: @teammate.id, completed_at: nil, deleted_at: nil })
        .pluck(:associable_type, :associable_id)
        .each_with_object({}) { |(type, id), h| h[[type, id]] = true }
    end

    def asana_source?
      @one_on_one_link.external_project_source == "asana"
    end

    def asana_cache
      @one_on_one_link.external_project_cache_for("asana")
    end

    def parse_due_on(value)
      return nil if value.blank?
      Date.parse(value)
    rescue ArgumentError
      nil
    end

    def format_task_item(item)
      due_on = parse_due_on(item["due_on"])
      due_label = due_on ? " (due #{due_on.strftime('%b %d')})" : ""
      "#{item["name"]}#{due_label}"
    end

    def format_task_link_item(item)
      label = format_task_item(item)
      gid = item["gid"].presence
      return label if gid.blank?

      { label: label, url: AsanaService.task_url(gid, asana_project_id_for_links) }
    end

    def asana_project_id_for_links
      @one_on_one_link.asana_project_id
    end

    def attention_priority(title, reason, concrete_items, cta_kind:, cta_label:, cta_associable: nil)
      items = concrete_items.compact
      {
        title: title,
        needs_attention: true,
        not_applicable: false,
        reason: reason,
        concrete_items: items.first(3),
        remaining_count: [items.count - 3, 0].max,
        cta_kind: cta_kind,
        cta_label: cta_label,
        cta_associable: cta_associable
      }
    end

    def success_priority(title, reason, concrete_items)
      items = concrete_items.compact
      {
        title: title,
        needs_attention: false,
        not_applicable: false,
        reason: reason,
        concrete_items: items.first(3),
        remaining_count: [items.count - 3, 0].max,
        cta_kind: nil,
        cta_label: nil,
        cta_associable: nil
      }
    end

    def not_applicable_priority(title)
      {
        title: title,
        needs_attention: false,
        not_applicable: true,
        reason: "Not applicable for this teammate right now.",
        concrete_items: [],
        remaining_count: 0,
        cta_kind: nil,
        cta_label: nil,
        cta_associable: nil
      }
    end
  end
end
