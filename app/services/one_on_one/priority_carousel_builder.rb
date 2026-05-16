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
        priority_target_unique_milestone_gaps_without_goals,
        priority_remaining_asana_tasks,
        priority_target_unique_required_assignments_without_goals
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
          "The 1:1 Asana project is linked but task data has not been synced yet. Sync the project so we can surface overdue and due-soon tasks in this queue.",
          [],
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
          "Urgent Asana work competes with everything else in the 1:1. When tasks are overdue or due within a week, review them in Asana and update plan or due dates so nothing critical slips.",
          [],
          cta_kind: :sync_anchor,
          cta_label: "Open urgent Asana tasks",
          data_kind: :asana_tasks_attention,
          items: tasks.map { |task| { task: task, project_id: asana_project_id_for_links } }
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

      item_data = rows.first(3).map { |row| blurred_or_obscured_item_data(row) }

      title = blurred_or_obscured_priority_title
      if rows.any?
        top_check_in_path = blurred_or_obscured_check_in_path(rows.first)
        top_check_in_path ||= review_most_recent_organization_company_teammate_check_ins_path(@organization, @teammate)
        attention_priority(
          title,
          "To achieve continuous clarity and continuous improvement all important check-ins should be made at least every 90 days. There are some opportunities for improving/keeping clarity high... so before the next 1:1, go complete one of the check-ins listed.",
          [],
          total_item_count: rows.count,
          cta_kind: :open_top_prioritized_check_in,
          cta_label: "Open top check-in",
          cta_path: top_check_in_path,
          data_kind: :blurred_or_obscured_attention,
          items: item_data
        )
      else
        success_priority(
          title,
          "Required check-ins are clear or crystal clear.",
          ["No blurred (#{blurred_check_in_age_hint}) or obscured (#{obscured_check_in_age_hint}) assignment, aspiration, or position check-ins were found."]
        )
      end
    end

    def blurred_or_obscured_priority_title
      "Are any position, assignment, or aspiration check-ins blurred (#{blurred_check_in_age_hint}) or obscured (#{obscured_check_in_age_hint})?"
    end

    def blurred_check_in_age_hint
      "check-in #{CheckInBehavior::CLARITY_CLEAR_DAYS}+ days old"
    end

    def obscured_check_in_age_hint
      "check-in #{CheckInBehavior::CLARITY_BLURRED_DAYS}+ days old"
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

    def blurred_or_obscured_item_data(row)
      {
        kind: row[:kind],
        record_id: row[:record_id],
        display_title: row[:display_title],
        finalized_at: row[:finalized_at],
        clarity: row[:clarity]
      }
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
          [],
          cta_kind: :check_ins_review_most_recent,
          cta_label: "Check-in status",
          cta_associable: nil,
          data_kind: :wtm_gap_without_goals_attention,
          items: gaps.map { |row| { associable: row[:associable] } }
        )
      elsif all_wtm.any?
        item_data = all_wtm.map { |row| wtm_working_to_meet_with_goals_item_data(row[:associable]) }
        success_priority(
          title,
          nil,
          [],
          display_item_limit: 5,
          total_item_count: item_data.size,
          data_kind: :wtm_with_goals_success,
          items: item_data
        )
      else
        data = wtm_all_clear_success_data(
          assignment_ids: assignment_ids,
          latest_assignment_check_ins: latest_assignment_check_ins,
          latest_aspiration_check_ins: latest_aspiration_check_ins
        )
        review_path = review_most_recent_organization_company_teammate_check_ins_path(@organization, @teammate)
        success_priority(
          title,
          nil,
          [],
          cta_kind: :check_ins_review_most_recent,
          cta_label: "More details",
          cta_path: review_path,
          data_kind: :wtm_all_clear_success,
          data: data
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

    def wtm_working_to_meet_with_goals_item_data(associable)
      {
        associable: associable,
        active_goal_count: active_goal_count_for_teammate_associable(associable)
      }
    end

    def wtm_all_clear_success_data(assignment_ids:, latest_assignment_check_ins:, latest_aspiration_check_ins:)
      x = assignment_ids.count { |aid| check_in_official_meeting_or_exceeding?(latest_assignment_check_ins[aid]) }
      aspiration_ids = Aspiration.within_hierarchy(@organization).pluck(:id)
      y = aspiration_ids.count { |aid| check_in_official_meeting_or_exceeding?(latest_aspiration_check_ins[aid]) }
      assignments_missing = assignment_ids.count { |aid| latest_assignment_check_ins[aid].blank? }
      aspirations_missing = aspiration_ids.count { |aid| latest_aspiration_check_ins[aid].blank? }

      {
        x: x,
        y: y,
        assignments_missing: assignments_missing,
        aspirations_missing: aspirations_missing
      }
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
          [],
          cta_kind: :my_growth_abilities,
          cta_label: "View all Ability Milestone Requirements",
          cta_associable: nil,
          data_kind: :milestone_gap_attention,
          items: rows.map { |row| { ability: row[:ability], required_level: row[:required_level], earned_level: row[:earned_level] } }
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
      given_relation = observations_given_to_others_last_30d_relation
      given_count = given_relation.count

      title = "Has #{teammate_casual_name} given a published observation to someone else in the last 30 days?"
      if given_count.zero?
        suggestion_rows = pick_feedback_opportunity_rows_with_distinct_others(
          observation_given_feedback_opportunity_rows.sort_by { |o| [-o[:sort_energy], o[:text].downcase] }
        )
        viewer_is_subject = @viewing_company_teammate.present? && @viewing_company_teammate.id == @teammate.id
        observation_given_explanation =
          "Published observations to others keep feedback flowing across the team. " \
          "When #{teammate_casual_name} has not given one in 30 days, use a specific opportunity below or start a new observation."
        if suggestion_rows.any?
          attention_priority(
            title,
            observation_given_explanation,
            [],
            total_item_count: suggestion_rows.size,
            display_item_limit: 5,
            cta_kind: viewer_is_subject ? :new_observation : :new_feedback_request,
            cta_label:
              if viewer_is_subject
                "Start an observation"
              else
                "Request feedback from #{teammate_casual_name} to someone else"
              end,
            data_kind: :observation_given_attention,
            items: suggestion_rows
          )
        else
          attention_priority(
            title,
            observation_given_explanation,
            [],
            cta_kind: viewer_is_subject ? :new_observation : :new_feedback_request,
            cta_label:
              if viewer_is_subject
                "Start an observation"
              else
                "Request feedback from #{teammate_casual_name} to someone else"
              end
          )
        end
      else
        data = observation_given_success_data(given_relation: given_relation, given_count: given_count)
        success_priority(
          title,
          nil,
          [],
          data_kind: :observation_given_success,
          data: data
        )
      end
    end

    def observation_given_success_data(given_relation:, given_count:)
      obs_ids = given_relation.unscope(:order).distinct.pluck(:id)
      observee_teammate_ids = Observee
        .where(observation_id: obs_ids)
        .where.not(teammate_id: @teammate.id)
        .distinct
        .pluck(:teammate_id)
      observees = CompanyTeammate
        .where(id: observee_teammate_ids, organization_id: @organization.id)
        .includes(:person)
        .to_a
        .sort_by { |tm| tm.person.casual_name.to_s.downcase }

      rating_pairs = ObservationRating
        .where(observation_id: obs_ids)
        .distinct
        .pluck(:rateable_type, :rateable_id)
      rateables = rating_pairs.filter_map do |type, id|
        next if type.blank? || id.blank?

        record = type.constantize.find_by(id: id)
        next unless record.is_a?(Assignment) || record.is_a?(Aspiration) || record.is_a?(Ability)

        record
      end

      { given_count: given_count, observees: observees, rateables: rateables }
    end

    def observations_given_to_others_last_30d_relation
      Observation
        .where(company: @organization, observer: @teammate.person, deleted_at: nil)
        .published
        .not_journal
        .where("observations.observed_at >= ?", @thirty_days_ago)
        .joins(:observees)
        .where.not(observees: { teammate_id: @teammate.id })
        .distinct
    end

    def priority_no_observation_received_30d
      recent_received = recent_received_non_journal_observations
      title = "Has #{teammate_casual_name} received a published observation in the last 30 days?"
      if recent_received.empty?
        suggestion_rows = pick_feedback_opportunity_rows_with_distinct_others(
          observation_received_feedback_opportunity_rows
        )
        feedback_new_path = new_organization_feedback_request_path(
          @organization,
          subject_of_feedback_teammate_id: @teammate.id
        )
        observation_received_explanation =
          "Fresh feedback helps #{teammate_casual_name} know how they are doing. " \
          "When no published observation arrived in 30 days, request feedback using a specific opportunity below."
        if suggestion_rows.any?
          attention_priority(
            title,
            observation_received_explanation,
            [],
            total_item_count: suggestion_rows.size,
            display_item_limit: 5,
            cta_kind: :new_feedback_request,
            cta_label: "Request feedback about #{teammate_casual_name}",
            cta_path: feedback_new_path,
            data_kind: :observation_received_attention,
            items: suggestion_rows
          )
        else
          attention_priority(
            title,
            observation_received_explanation,
            [],
            cta_kind: :new_feedback_request,
            cta_label: "Request feedback about #{teammate_casual_name}",
            cta_path: feedback_new_path
          )
        end
      else
        total = recent_received.size
        display_limit = 5
        items = recent_received.first(display_limit).map { |obs| observation_received_item_data(obs) }
        success_priority(
          title,
          "#{total} Published non-journal observations were received in the last 30 days.",
          [],
          display_item_limit: display_limit,
          total_item_count: total,
          data_kind: :observation_received_success,
          data: { total: total },
          items: items
        )
      end
    end

    def observation_received_item_data(observation)
      observer_teammate = CompanyTeammate.find_by(organization_id: observation.company_id, person_id: observation.observer_id)
      rateables = observation.observation_ratings.filter_map(&:rateable).select do |r|
        r.is_a?(Assignment) || r.is_a?(Aspiration) || r.is_a?(Ability)
      end
      {
        kind: :received_observation,
        observation: observation,
        observer_teammate: observer_teammate,
        rateables: rateables
      }
    end

    def priority_no_wtm_observation_received_30d
      item_data = wtm_items_without_received_observations
      title = "Have all working-to-meet assignments and aspirational values received an observation in the last 30 days?"
      if item_data.any?
        feedback_new_path = new_organization_feedback_request_path(
          @organization,
          subject_of_feedback_teammate_id: @teammate.id
        )
        attention_priority(
          title,
          "Working-to-meet areas need recent feedback so growth stays targeted. " \
          "When an assignment or aspiration rated working to meet has no published observation in 30 days, request feedback on that area.",
          [],
          total_item_count: item_data.size,
          display_item_limit: 5,
          cta_kind: :new_feedback_request,
          cta_label: "Request feedback about #{teammate_casual_name}",
          cta_path: feedback_new_path,
          data_kind: :wtm_missing_observation_attention,
          items: item_data
        )
      else
        associables = wtm_all_working_to_meet_associables
        area_rows = associables.map do |associable|
          { associable: associable, observations: wtm_covering_observations_for_associable(associable) }
        end
        covering_ids = area_rows.each_with_object(Set.new) do |row, memo|
          row[:observations].each { |o| memo.add(o.id) }
        end
        x = associables.size
        y = covering_ids.size
        display_limit = 5
        items = area_rows.first(display_limit).map { |row| wtm_received_item_data(row) }
        success_priority(
          title,
          nil,
          [],
          display_item_limit: display_limit,
          total_item_count: area_rows.size,
          data_kind: :wtm_received_success,
          data: { x: x, y: y },
          items: items
        )
      end
    end

    def wtm_received_item_data(row)
      observations = Array(row[:observations])
      by_observer = observations.group_by(&:observer_id)
      observers_with_observations = by_observer.keys.sort_by do |pid|
        by_observer[pid].first.observer.casual_name.to_s.downcase
      end.map do |pid|
        obs_for_person = by_observer[pid]
        { person: obs_for_person.first.observer, observations: obs_for_person }
      end

      {
        kind: :wtm_area,
        associable: row[:associable],
        observers_with_observations: observers_with_observations
      }
    end

    def wtm_all_working_to_meet_associables
      latest_assignment_check_ins = AssignmentCheckIn.where(company_teammate: @teammate).closed.order(official_check_in_completed_at: :desc).index_by(&:assignment_id)
      latest_aspiration_check_ins = AspirationCheckIn.where(company_teammate: @teammate).closed.order(official_check_in_completed_at: :desc).index_by(&:aspiration_id)
      out = []
      latest_assignment_check_ins.each_value do |check_in|
        next unless check_in.official_rating == "working_to_meet"

        assignment = Assignment.find_by(id: check_in.assignment_id)
        out << assignment if assignment.present?
      end
      latest_aspiration_check_ins.each_value do |check_in|
        next unless check_in.official_rating == "working_to_meet"

        aspiration = Aspiration.find_by(id: check_in.aspiration_id)
        out << aspiration if aspiration.present?
      end
      out.uniq.sort_by { |associable| wtm_gap_without_goals_sort_key(associable) }
    end

    def wtm_covering_observations_for_associable(associable)
      scope = Observation.joins(:observees, :observation_ratings)
        .where(company: @organization, deleted_at: nil)
        .published
        .not_journal
        .where("observations.observed_at >= ?", @thirty_days_ago)
        .where(observees: { teammate_id: @teammate.id })
      scope =
        case associable
        when Assignment
          scope.where(observation_ratings: { rateable_type: "Assignment", rateable_id: associable.id })
        when Aspiration
          scope.where(observation_ratings: { rateable_type: "Aspiration", rateable_id: associable.id })
        else
          return []
        end
      scope.distinct.order(observed_at: :desc).includes(:observer).to_a
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
          "Goals can drift to the background if we don't check in on them. Let's take the time to state how confident we are in hitting these goals:",
          [],
          total_item_count: stale.size,
          display_item_limit: 5,
          cta_kind: :my_growth_goals,
          cta_label: "Grow by goals",
          data_kind: :stale_goals_attention,
          items: stale.map { |goal| { goal: goal } }
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
          "The 1:1 Asana project is linked but task data has not been synced yet. Sync the project so we can evaluate remaining incomplete tasks.",
          [],
          cta_kind: :sync_anchor,
          cta_label: "Sync Asana now"
        )
      end

      remaining = cache.incomplete_items.sort_by { |item| [(item["name"] || "").downcase] }
      if remaining.any?
        attention_priority(
          REMAINING_ASANA_TASKS_TITLE,
          "Clearing the linked Asana project keeps execution aligned with the 1:1. " \
          "When incomplete tasks remain, review them in Asana and close or reschedule what is no longer needed.",
          [],
          cta_kind: :sync_anchor,
          cta_label: "Open remaining tasks",
          data_kind: :asana_tasks_attention,
          items: remaining.map { |task| { task: task, project_id: asana_project_id_for_links } }
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
          "Active goals give #{teammate_casual_name} a concrete path for growth. " \
          "When there are no active goals, create at least one goal to anchor the 1:1 conversation.",
          [],
          cta_kind: :bulk_goals,
          cta_label: "Create goals"
        )
      else
        success_priority(
          title,
          nil,
          [],
          data_kind: :no_active_goals_success,
          data: { active_goal_count: active_goal_count }
        )
      end
    end

    def priority_target_unique_required_assignments_without_goals
      rows = target_unique_required_assignment_rows
      title = "Are required assignments unique to #{target_position_title} still missing active goals?"
      if rows.any?
        attention_priority(
          title,
          "Whenever a required assignment is unique to the target position and still has no active goal, we should have goals that make the path to meeting expectations in that assignment concrete.",
          [],
          cta_kind: :my_growth_experiences,
          cta_label: "Grow by experiences",
          cta_associable: nil,
          data_kind: :wtm_gap_without_goals_attention,
          items: rows.map { |row| { associable: row[:assignment] } }
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
      rows.sort_by! do |row|
        gap = row[:required_level].to_i - row[:earned_level].to_i
        [-gap, row[:ability].name.downcase]
      end
      title = "Are ability milestones unique to #{target_position_title} below target still missing active goals?"
      if rows.any?
        attention_priority(
          title,
          "Whenever we are below the milestone target for an ability unique to the target position, we should have goals that make the path to the required level concrete.",
          [],
          cta_kind: :my_growth_abilities,
          cta_label: "View all Ability Milestone Requirements",
          cta_associable: nil,
          data_kind: :milestone_gap_attention,
          items: rows.map { |row| { ability: row[:ability], required_level: row[:required_level], earned_level: row[:earned_level] } }
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
        rows << { kind: :assignment, record: assignment, fallback_id: check_in.assignment_id }
      end

      latest_aspiration_check_ins.each_value do |check_in|
        next unless check_in.official_rating == "working_to_meet"
        next if recent_aspiration_ids.include?(check_in.aspiration_id)

        aspiration = Aspiration.find_by(id: check_in.aspiration_id)
        rows << { kind: :aspiration, record: aspiration, fallback_id: check_in.aspiration_id }
      end

      rows.sort_by { |row| wtm_missing_observation_sort_key(row) }
    end

    def wtm_missing_observation_sort_key(row)
      case row[:kind]
      when :assignment then "assignment:#{(row[:record]&.title || "Assignment ##{row[:fallback_id]}").downcase}"
      when :aspiration then "aspiration:#{(row[:record]&.name || "Aspiration ##{row[:fallback_id]}").downcase}"
      else ""
      end
    end

    def recent_received_non_journal_observations
      Observation.joins(:observees)
        .where(company: @organization, deleted_at: nil)
        .published
        .not_journal
        .where("observations.observed_at >= ?", @thirty_days_ago)
        .where(observees: { teammate_id: @teammate.id })
        .includes(:observer, observation_ratings: :rateable)
        .order(observed_at: :desc)
        .distinct
        .to_a
    end

    def observation_given_feedback_suggestion_bullets
      ordered = observation_given_feedback_opportunity_rows.sort_by { |o| [-o[:sort_energy], o[:text].downcase] }
      pick_feedback_opportunity_lines_with_distinct_others(ordered)
    end

    def observation_given_feedback_opportunity_rows
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
              other_teammate: other_tm,
              sort_energy: energy,
              scenario: :given_supplier_chain,
              consumer_assignment: consumer_assignment,
              supplier_assignment: supplier_assignment,
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
            other_teammate: other_tm,
            sort_energy: energy,
            scenario: :given_shared_assignment,
            assignment: assignment,
            text: "#{focus_casual} could give feedback to #{other_casual}, since they are both taking on #{assignment.title}."
          }
        end
      end

      opportunities
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
      pick_feedback_opportunity_lines_with_distinct_others(observation_received_feedback_opportunity_rows)
    end

    def observation_received_feedback_opportunity_rows
      consumer_ops = observation_received_consumer_chain_opportunities
      shared_ops = observation_received_shared_assignment_opportunities

      primary_sorted = consumer_ops.sort_by { |o| [-o[:sort_energy], o[:text].downcase] }
      secondary_sorted = shared_ops.sort_by { |o| [-o[:sort_energy], o[:text].downcase] }
      primary_sorted + secondary_sorted
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
              other_teammate: other_tm,
              sort_energy: energy,
              scenario: :received_consumer_chain,
              consumer_assignment: consumer_assignment,
              supplier_assignment: supplier_assignment,
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
            other_teammate: other_tm,
            sort_energy: energy,
            scenario: :received_shared_assignment,
            assignment: assignment,
            text: "#{other_casual} could give feedback to #{focus_casual}, since they are both taking on #{assignment.title}."
          }
        end
      end

      opportunities
    end

    def pick_feedback_opportunity_rows_with_distinct_others(ordered_rows, limit: OBSERVATION_FEEDBACK_OPPORTUNITY_LIMIT)
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

      chosen
    end

    def pick_feedback_opportunity_lines_with_distinct_others(ordered_rows, limit: OBSERVATION_FEEDBACK_OPPORTUNITY_LIMIT)
      pick_feedback_opportunity_rows_with_distinct_others(ordered_rows, limit: limit).map { |r| r[:text] }
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

    def asana_project_id_for_links
      @one_on_one_link.asana_project_id
    end

    def attention_priority(title, reason, concrete_items, cta_kind:, cta_label:, cta_associable: nil, total_item_count: nil, cta_path: nil, display_item_limit: nil, data_kind: nil, data: nil, items: nil)
      legacy_items = concrete_items.compact
      total = total_item_count.presence || legacy_items.count
      limit = display_item_limit.presence || 3
      row = {
        title: title,
        needs_attention: true,
        not_applicable: false,
        reason: reason,
        concrete_items: legacy_items.first(limit),
        remaining_count: [total - limit, 0].max,
        cta_kind: cta_kind,
        cta_label: cta_label,
        cta_associable: cta_associable,
        cta_path: cta_path
      }
      row[:data_kind] = data_kind if data_kind
      row[:data] = data if data
      row[:items] = items.first(limit) if items.is_a?(Array)
      row
    end

    def success_priority(title, reason, concrete_items, display_item_limit: nil, total_item_count: nil, cta_kind: nil, cta_label: nil, cta_path: nil, cta_associable: nil, data_kind: nil, data: nil, items: nil)
      legacy_items = concrete_items.compact
      limit = display_item_limit.presence || 3
      total = total_item_count.presence || legacy_items.count
      row = {
        title: title,
        needs_attention: false,
        not_applicable: false,
        reason: reason,
        concrete_items: legacy_items.first(limit),
        remaining_count: [total - limit, 0].max,
        cta_kind: cta_kind,
        cta_label: cta_label,
        cta_associable: cta_associable,
        cta_path: cta_path
      }
      row[:data_kind] = data_kind if data_kind
      row[:data] = data if data
      row[:items] = items.first(limit) if items.is_a?(Array)
      row
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
