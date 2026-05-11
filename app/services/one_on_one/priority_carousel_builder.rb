# frozen_string_literal: true
require "set"

module OneOnOne
  class PriorityCarouselBuilder
    include Rails.application.routes.url_helpers

    ASANA_URGENT_TASKS_TITLE = "Are there overdue or due-soon Asana tasks?".freeze
    REMAINING_ASANA_TASKS_TITLE = "Are there incomplete tasks remaining in the linked Asana project?".freeze
    OBSERVATION_FEEDBACK_OPPORTUNITY_LIMIT = 5

    def self.call(...) = new(...).call

    def initialize(organization:, teammate:, one_on_one_link:, viewing_company_teammate: nil)
      @organization = organization
      @teammate = teammate
      @one_on_one_link = one_on_one_link
      @viewing_company_teammate = viewing_company_teammate
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
      rows = blurred_or_obscured_check_in_rows

      rows.sort_by! do |row|
        CheckIns::RequiredCheckInUrgencySort.sort_tuple(
          row[:clarity],
          row[:kind],
          row[:finalized_at],
          row[:rating]
        )
      end

      concrete_items = rows.first(3).map { |row| blurred_or_obscured_row_to_link_item(row) }

      title = "Are any position, assignment, or aspiration check-ins blurred or obscured?"
      if rows.any?
        top_check_in_path = blurred_or_obscured_check_in_path(rows.first)
        top_check_in_path ||= review_most_recent_organization_company_teammate_check_ins_path(@organization, @teammate)
        attention_priority(
          title,
          nil,
          concrete_items,
          total_item_count: rows.count,
          cta_kind: :open_top_prioritized_check_in,
          cta_label: "Open top check-in",
          cta_path: top_check_in_path
        )
      else
        success_priority(
          title,
          "Required check-ins are clear or crystal clear.",
          ["No blurred or obscured assignment, aspiration, or position check-ins were found."]
        )
      end
    end

    def blurred_or_obscured_check_in_rows
      rows = []

      position = @teammate.active_employment_tenure&.position
      pos_check_in = PositionCheckIn.latest_finalized_for(@teammate)
      pos_clarity = pos_check_in&.clarity_level || :obscured
      if %i[blurred obscured].include?(pos_clarity)
        rows << {
          kind: :position,
          clarity: pos_clarity,
          finalized_at: pos_check_in&.official_check_in_completed_at,
          rating: pos_check_in&.official_rating,
          record_id: position&.id,
          display_title: position&.display_name || "Current position"
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
          kind: :assignment,
          clarity: clarity,
          finalized_at: latest&.official_check_in_completed_at,
          rating: latest&.official_rating,
          record_id: assignment.id,
          display_title: assignment.title
        }
      end

      Aspiration.within_hierarchy(@organization).find_each do |aspiration|
        latest = AspirationCheckIn.latest_finalized_for(@teammate, aspiration)
        clarity = latest&.clarity_level || :obscured
        next unless %i[blurred obscured].include?(clarity)

        rows << {
          kind: :aspiration,
          clarity: clarity,
          finalized_at: latest&.official_check_in_completed_at,
          rating: latest&.official_rating,
          record_id: aspiration.id,
          display_title: aspiration.name
        }
      end

      rows
    end

    def blurred_or_obscured_row_to_link_item(row)
      label_parts = [
        blurred_or_obscured_kind_prefix(row[:kind]),
        row[:display_title],
        "(Last check-in: #{blurred_or_obscured_last_check_in_words(row[:finalized_at])})"
      ].join(" ")

      {
        label: label_parts,
        url: blurred_or_obscured_check_in_path(row)
      }
    end

    def blurred_or_obscured_kind_prefix(kind)
      case kind
      when :aspiration then "Aspiration:"
      when :assignment then "Assignment:"
      when :position then "Position:"
      else "Check-in:"
      end
    end

    def blurred_or_obscured_last_check_in_words(completed_at)
      return "never" if completed_at.blank?

      h = ApplicationController.helpers
      "#{h.time_ago_in_words(completed_at)} ago"
    end

    def blurred_or_obscured_check_in_path(row)
      case row[:kind]
      when :aspiration
        organization_teammate_aspiration_path(@organization, @teammate, row[:record_id])
      when :assignment
        organization_teammate_assignment_path(@organization, @teammate, row[:record_id])
      when :position
        position_check_in_organization_teammate_path(@organization, @teammate)
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

      gaps = []
      all_wtm = []

      assignment_ids.each do |assignment_id|
        check_in = latest_assignment_check_ins[assignment_id]
        next unless check_in&.official_rating == "working_to_meet"

        assignment = Assignment.find_by(id: assignment_id)
        next if assignment.blank?

        all_wtm << { associable: assignment }
        next if @active_goal_lookup[["Assignment", assignment_id]]

        gaps << { associable: assignment }
      end

      latest_aspiration_check_ins.values.each do |check_in|
        next unless check_in.official_rating == "working_to_meet"

        aspiration = Aspiration.find_by(id: check_in.aspiration_id)
        next if aspiration.blank?

        all_wtm << { associable: aspiration }
        next if @active_goal_lookup[["Aspiration", check_in.aspiration_id]]

        gaps << { associable: aspiration }
      end

      gaps.sort_by! { |row| wtm_gap_without_goals_sort_key(row[:associable]) }
      all_wtm.sort_by! { |row| wtm_gap_without_goals_sort_key(row[:associable]) }

      title = "Are any working-to-meet assignments or aspirational values missing active goals?"
      if gaps.any?
        attention_priority(
          title,
          "Whenever we are working to meet expectations, we should have goals that help give clarity as to what has to be done in order to be meeting expectations",
          gaps.map { |row| wtm_gap_without_goals_item(row[:associable]) },
          cta_kind: :check_ins_review_most_recent,
          cta_label: "Check-in status",
          cta_associable: nil
        )
      elsif all_wtm.any?
        concrete = all_wtm.map { |row| wtm_working_to_meet_with_goals_item(row[:associable]) }
        success_priority(
          title,
          nil,
          concrete,
          display_item_limit: 5,
          total_item_count: concrete.size
        )
      else
        reason_lines = wtm_all_clear_reason_lines(
          assignment_ids: assignment_ids,
          latest_assignment_check_ins: latest_assignment_check_ins,
          latest_aspiration_check_ins: latest_aspiration_check_ins
        )
        review_path = review_most_recent_organization_company_teammate_check_ins_path(@organization, @teammate)
        success_priority(
          title,
          reason_lines,
          [],
          cta_kind: :check_ins_review_most_recent,
          cta_label: "More details",
          cta_path: review_path
        )
      end
    end

    def active_goal_count_for_teammate_associable(associable)
      GoalAssociation
        .joins(:goal)
        .where(associable: associable)
        .where(goals: { owner_type: "CompanyTeammate", owner_id: @teammate.id, completed_at: nil, deleted_at: nil })
        .distinct
        .count(:goal_id)
    end

    def wtm_working_to_meet_with_goals_item(associable)
      n = active_goal_count_for_teammate_associable(associable)
      h = ApplicationController.helpers
      goal_phrase = h.pluralize(n, "active goal")
      label =
        case associable
        when Assignment
          "Assignment: #{associable.title} (#{goal_phrase})"
        when Aspiration
          "Aspiration: #{associable.name} (#{goal_phrase})"
        else
          raise ArgumentError, "Unsupported associable for WTM with goals item: #{associable.class.name}"
        end

      url =
        case associable
        when Assignment
          organization_teammate_assignment_path(@organization, @teammate, associable)
        when Aspiration
          organization_teammate_aspiration_path(@organization, @teammate, associable)
        end

      { label: label, url: url }
    end

    def wtm_all_clear_reason_lines(assignment_ids:, latest_assignment_check_ins:, latest_aspiration_check_ins:)
      casual = teammate_casual_name
      h = ApplicationController.helpers
      x = assignment_ids.count { |aid| check_in_official_meeting_or_exceeding?(latest_assignment_check_ins[aid]) }
      aspiration_ids = Aspiration.within_hierarchy(@organization).pluck(:id)
      y = aspiration_ids.count { |aid| check_in_official_meeting_or_exceeding?(latest_aspiration_check_ins[aid]) }

      expectations_line =
        "#{casual} is meeting or exceeding expectations for #{h.pluralize(x, 'required and active assignment')} " \
          "and #{h.pluralize(y, 'aspirational value')}."

      assignments_missing = assignment_ids.count { |aid| latest_assignment_check_ins[aid].blank? }
      aspirations_missing = aspiration_ids.count { |aid| latest_aspiration_check_ins[aid].blank? }

      check_ins_line =
        if assignments_missing.zero? && aspirations_missing.zero?
          "#{casual} has had all relevant check-ins."
        elsif assignments_missing.positive? && aspirations_missing.positive?
          "#{casual} has not had a check-in on #{h.pluralize(assignments_missing, 'required or active assignment')} " \
            "and #{h.pluralize(aspirations_missing, 'aspirational value')}."
        elsif assignments_missing.positive?
          "#{casual} has not had a check-in on #{h.pluralize(assignments_missing, 'required or active assignment')}."
        else
          "#{casual} has not had a check-in on #{h.pluralize(aspirations_missing, 'aspirational value')}."
        end

      [expectations_line, check_ins_line]
    end

    def check_in_official_meeting_or_exceeding?(check_in)
      check_in.present? && %w[meeting exceeding].include?(check_in.official_rating)
    end

    def wtm_gap_without_goals_sort_key(associable)
      case associable
      when Assignment
        "assignment:#{associable.title}"
      when Aspiration
        "aspiration:#{associable.name}"
      else
        ""
      end.downcase
    end

    def wtm_gap_without_goals_item(associable)
      label =
        case associable
        when Assignment
          "Assignment: #{associable.title}"
        when Aspiration
          "Aspiration: #{associable.name}"
        else
          raise ArgumentError, "Unsupported associable for WTM gap item: #{associable.class.name}"
        end

      lens_url =
        case associable
        when Assignment
          organization_teammate_assignment_path(@organization, @teammate, associable)
        when Aspiration
          organization_teammate_aspiration_path(@organization, @teammate, associable)
        end

      initials = @teammate.person.max_two_initials.presence || "?"
      kind_phrase = associable.is_a?(Assignment) ? "assignment" : "aspirational value"
      add_goal_label = "Add goal for #{initials} + this #{kind_phrase}"

      add_goal_url =
        case associable
        when Assignment
          choose_manage_goals_organization_assignment_path(
            @organization,
            associable,
            return_url: one_on_one_hub_return_path,
            return_text: "Back to 1:1 Hub",
            for_company_teammate_id: @teammate.id
          )
        when Aspiration
          choose_manage_goals_organization_aspiration_path(
            @organization,
            associable,
            return_url: one_on_one_hub_return_path,
            return_text: "Back to 1:1 Hub",
            for_company_teammate_id: @teammate.id
          )
        end

      {
        label: label,
        url: lens_url,
        add_goal_url: add_goal_url,
        add_goal_label: add_goal_label
      }
    end

    def one_on_one_hub_return_path
      organization_company_teammate_one_on_one_link_path(@organization, @teammate)
    end

    def current_position_milestone_gap_item(row)
      ability = row[:ability]
      required = row[:required_level]
      earned = row[:earned_level]
      label = "Ability: #{ability.name} (need M#{required}, earned M#{earned})"
      lens_url = organization_teammate_ability_path(@organization, @teammate, ability)
      initials = @teammate.person.max_two_initials.presence || "?"
      add_goal_label = "Add goal for #{initials} + this ability"
      add_goal_url = choose_manage_goals_organization_ability_path(
        @organization,
        ability,
        return_url: one_on_one_hub_return_path,
        return_text: "Back to 1:1 Hub",
        for_company_teammate_id: @teammate.id
      )

      {
        label: label,
        url: lens_url,
        add_goal_url: add_goal_url,
        add_goal_label: add_goal_label
      }
    end

    def priority_current_position_milestone_gaps_without_goals
      rows = current_position_ability_gaps_without_goals
      rows.sort_by! do |row|
        gap = row[:required_level].to_i - row[:earned_level].to_i
        [-gap, row[:ability].name.downcase]
      end
      title = "Are any #{current_position_title} ability milestones below target missing active goals?"
      if rows.any?
        attention_priority(
          title,
          "Whenever we are below the milestone target for an ability required by the current position, we should have goals that make the path to the required level concrete.",
          rows.map { |row| current_position_milestone_gap_item(row) },
          cta_kind: :my_growth_abilities,
          cta_label: "View all Ability Milestone Requirements",
          cta_associable: nil
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
        suggestions = observation_given_feedback_suggestion_bullets
        concrete =
          if suggestions.any?
            suggestions
          else
            ["Give one concrete observation to support someone else this week."]
          end
        total_count = concrete.size
        viewer_is_subject = @viewing_company_teammate.present? && @viewing_company_teammate.id == @teammate.id
        attention_priority(
          title,
          "No published non-journal observation was given to someone else in the last 30 days.",
          concrete,
          total_item_count: total_count,
          display_item_limit: 5,
          cta_kind: viewer_is_subject ? :new_observation : :new_feedback_request,
          cta_label:
            if viewer_is_subject
              "Start an observation"
            else
              "Request feedback from #{teammate_casual_name} to someone else"
            end
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
        suggestions = observation_received_feedback_suggestion_bullets
        concrete =
          if suggestions.any?
            suggestions
          else
            ["Request fresh feedback to keep clarity high."]
          end
        total_count = concrete.size
        feedback_new_path = new_organization_feedback_request_path(
          @organization,
          subject_of_feedback_teammate_id: @teammate.id
        )
        attention_priority(
          title,
          "No published non-journal observation was received in the last 30 days.",
          concrete,
          total_item_count: total_count,
          display_item_limit: 5,
          cta_kind: :new_feedback_request,
          cta_label: "Request feedback about #{teammate_casual_name}",
          cta_path: feedback_new_path
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
        feedback_new_path = new_organization_feedback_request_path(
          @organization,
          subject_of_feedback_teammate_id: @teammate.id
        )
        attention_priority(
          title,
          "At least one working-to-meet assignment/aspiration has no published non-journal observation in the last 30 days.",
          rows,
          total_item_count: rows.size,
          display_item_limit: 5,
          cta_kind: :new_feedback_request,
          cta_label: "Request feedback about #{teammate_casual_name}",
          cta_path: feedback_new_path
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
        concrete = stale.map do |goal|
          { label: goal.title, url: organization_goal_path(@organization, goal) }
        end
        attention_priority(
          title,
          "Goals can drift to the background if we don't check in on them. Let's take the time to state how confident we are in hitting these goals:",
          concrete,
          total_item_count: stale.size,
          display_item_limit: 5,
          cta_kind: :my_growth_goals,
          cta_label: "Grow by goals"
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

    def wtm_missing_observation_list_item(label, url)
      return label if url.blank?

      { label: label, url: url }
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
        label = "Assignment: #{assignment&.title || "Assignment ##{check_in.assignment_id}"}"
        url = assignment.present? ? organization_teammate_assignment_path(@organization, @teammate, assignment) : nil
        rows << wtm_missing_observation_list_item(label, url)
      end

      latest_aspiration_check_ins.each_value do |check_in|
        next unless check_in.official_rating == "working_to_meet"
        next if recent_aspiration_ids.include?(check_in.aspiration_id)
        aspiration = Aspiration.find_by(id: check_in.aspiration_id)
        label = "Aspiration: #{aspiration&.name || "Aspiration ##{check_in.aspiration_id}"}"
        url = aspiration.present? ? organization_teammate_aspiration_path(@organization, @teammate, aspiration) : nil
        rows << wtm_missing_observation_list_item(label, url)
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

    def observation_given_feedback_suggestion_bullets
      focus_casual = teammate_casual_name
      opportunities = []

      active_tenures = AssignmentTenure
        .active
        .where(teammate_id: @teammate.id)
        .joins(:assignment)
        .merge(Assignment.unarchived)
        .includes(assignment: :supplier_assignments)

      active_tenures.each do |tenure|
        consumer_assignment = tenure.assignment
        energy = tenure.anticipated_energy_percentage.to_i
        consumer_assignment.supplier_assignments.each do |supplier_assignment|
          next if supplier_assignment.deleted_at.present?

          other_active_tenures_for_assignment(supplier_assignment.id).each do |other_tenure|
            other_tm = other_tenure.company_teammate
            next if other_tm.blank?

            other_casual = other_tm.person.casual_name
            opportunities << {
              other_teammate_id: other_tm.id,
              sort_energy: energy,
              text: "Since #{consumer_assignment.title} relies on #{supplier_assignment.title}, #{focus_casual} " \
                    "(taking on #{consumer_assignment.title}) could give feedback to #{other_casual} " \
                    "(taking on #{supplier_assignment.title})."
            }
          end
        end
      end

      active_tenures.each do |tenure|
        assignment = tenure.assignment
        energy = tenure.anticipated_energy_percentage.to_i
        other_active_tenures_for_assignment(assignment.id).each do |other_tenure|
          other_tm = other_tenure.company_teammate
          next if other_tm.blank?

          other_casual = other_tm.person.casual_name
          opportunities << {
            other_teammate_id: other_tm.id,
            sort_energy: energy,
            text: "#{focus_casual} could give feedback to #{other_casual}, since they are both taking on #{assignment.title}."
          }
        end
      end

      ordered = opportunities.sort_by { |o| [-o[:sort_energy], o[:text].downcase] }
      pick_feedback_opportunity_lines_with_distinct_others(ordered)
    end

    def other_active_tenures_for_assignment(assignment_id)
      AssignmentTenure
        .active
        .where.not(teammate_id: @teammate.id)
        .where(assignment_id: assignment_id)
        .joins(:assignment)
        .merge(Assignment.unarchived)
        .joins(:company_teammate)
        .where(teammates: { organization_id: @organization.id })
        .includes(company_teammate: :person)
    end

    def observation_received_feedback_suggestion_bullets
      consumer_ops = observation_received_consumer_chain_opportunities
      shared_ops = observation_received_shared_assignment_opportunities

      primary_sorted = consumer_ops.sort_by { |o| [-o[:sort_energy], o[:text].downcase] }
      secondary_sorted = shared_ops.sort_by { |o| [-o[:sort_energy], o[:text].downcase] }
      ordered = primary_sorted + secondary_sorted
      pick_feedback_opportunity_lines_with_distinct_others(ordered)
    end

    def observation_received_consumer_chain_opportunities
      focus_casual = teammate_casual_name
      opportunities = []

      active_tenures = AssignmentTenure
        .active
        .where(teammate_id: @teammate.id)
        .joins(:assignment)
        .merge(Assignment.unarchived)
        .includes(assignment: :consumer_assignments)

      active_tenures.each do |tenure|
        supplier_assignment = tenure.assignment
        energy = tenure.anticipated_energy_percentage.to_i
        supplier_assignment.consumer_assignments.each do |consumer_assignment|
          next if consumer_assignment.deleted_at.present?

          other_active_tenures_for_assignment(consumer_assignment.id).each do |other_tenure|
            other_tm = other_tenure.company_teammate
            next if other_tm.blank?

            other_casual = other_tm.person.casual_name
            opportunities << {
              other_teammate_id: other_tm.id,
              sort_energy: energy,
              text: "#{other_casual} (taking on #{consumer_assignment.title}) could give feedback to #{focus_casual} " \
                    "(taking on #{supplier_assignment.title}), since #{consumer_assignment.title} relies on #{supplier_assignment.title}."
            }
          end
        end
      end

      opportunities
    end

    def observation_received_shared_assignment_opportunities
      focus_casual = teammate_casual_name
      opportunities = []

      active_tenures = AssignmentTenure
        .active
        .where(teammate_id: @teammate.id)
        .joins(:assignment)
        .merge(Assignment.unarchived)

      active_tenures.each do |tenure|
        assignment = tenure.assignment
        energy = tenure.anticipated_energy_percentage.to_i
        other_active_tenures_for_assignment(assignment.id).each do |other_tenure|
          other_tm = other_tenure.company_teammate
          next if other_tm.blank?

          other_casual = other_tm.person.casual_name
          opportunities << {
            other_teammate_id: other_tm.id,
            sort_energy: energy,
            text: "#{other_casual} could give feedback to #{focus_casual}, since they are both taking on #{assignment.title}."
          }
        end
      end

      opportunities
    end

    def pick_feedback_opportunity_lines_with_distinct_others(ordered_rows, limit: OBSERVATION_FEEDBACK_OPPORTUNITY_LIMIT)
      chosen = []
      seen_other_ids = Set.new

      ordered_rows.each do |row|
        break if chosen.size >= limit

        oid = row[:other_teammate_id]
        next if seen_other_ids.include?(oid)

        seen_other_ids.add(oid)
        chosen << row
      end

      ordered_rows.each do |row|
        break if chosen.size >= limit
        next if chosen.any? { |c| c[:text] == row[:text] }

        chosen << row
      end

      chosen.pluck(:text)
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

    def attention_priority(title, reason, concrete_items, cta_kind:, cta_label:, cta_associable: nil, total_item_count: nil, cta_path: nil, display_item_limit: nil)
      items = concrete_items.compact
      total = total_item_count.presence || items.count
      limit = display_item_limit.presence || 3
      {
        title: title,
        needs_attention: true,
        not_applicable: false,
        reason: reason,
        concrete_items: items.first(limit),
        remaining_count: [total - limit, 0].max,
        cta_kind: cta_kind,
        cta_label: cta_label,
        cta_associable: cta_associable,
        cta_path: cta_path
      }
    end

    def success_priority(title, reason, concrete_items, display_item_limit: nil, total_item_count: nil, cta_kind: nil, cta_label: nil, cta_path: nil, cta_associable: nil)
      items = concrete_items.compact
      limit = display_item_limit.presence || 3
      total = total_item_count.presence || items.count
      {
        title: title,
        needs_attention: false,
        not_applicable: false,
        reason: reason,
        concrete_items: items.first(limit),
        remaining_count: [total - limit, 0].max,
        cta_kind: cta_kind,
        cta_label: cta_label,
        cta_associable: cta_associable,
        cta_path: cta_path
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
