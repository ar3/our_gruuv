# frozen_string_literal: true

require "set"

module PositionChange
  # Keystone goals and derived eligibility-conversation date for Position / Title Change.
  #
  # Keystones = goals linked to target-required assignments/abilities, or to WTM items.
  # Conversation date = latest most_likely among incomplete keystones when the path is fully
  # covered; otherwise nil. Soft copy only — does not change formal eligibility rules.
  class KeystoneEligibilityConversation
    Gap = Data.define(:kind, :record, :label, :detail)

    PathRow = Data.define(
      :record,
      :object_label,
      :object_type_label,
      :reason,
      :goal,
      :goal_status
    )

    Result = Data.define(
      :keystone_goals,
      :uncovered_blocking_gaps,
      :path_rows,
      :conversation_date,
      :prompt_kind,
      :employee_casual_name,
      :manager_casual_name,
      :target_equals_current,
      :target_eligible
    )

    PROMPT_SUGGEST_DIFFERENT_TARGET = :suggest_different_target
    PROMPT_READY_NOW = :ready_now
    PROMPT_SCHEDULED = :scheduled
    PROMPT_INCOMPLETE_PATH = :incomplete_path
    PROMPT_NEEDS_EXCEED_GOALS = :needs_exceed_goals

    EXCEED_REASON = "Set a goal to exceed expectations"
    EXCEED_CHECK_KEYS = %i[
      required_assignment_check_in_requirements
      unique_to_you_assignment_check_in_requirements
      company_aspirational_values_check_in_requirements
    ].freeze

    def self.call(teammate:, target_position:, target_eligible: nil, eligibility_report: nil)
      eligible =
        if eligibility_report
          eligibility_report[:overall_eligible]
        else
          target_eligible
        end
      checks = eligibility_report&.dig(:checks) || []

      new(
        teammate: teammate,
        target_position: target_position,
        target_eligible: eligible,
        eligibility_checks: checks
      ).call
    end

    def initialize(teammate:, target_position:, target_eligible:, eligibility_checks: [])
      @teammate = teammate
      @target_position = target_position
      @target_eligible = target_eligible
      @eligibility_checks = Array(eligibility_checks)
    end

    def call
      return empty_result unless target_position

      goals = keystone_goals
      gaps = uncovered_blocking_gaps
      incomplete = goals.select { |g| g.completed_at.nil? }
      conversation_date = derive_conversation_date(incomplete: incomplete, gaps: gaps)
      prompt_kind = derive_prompt_kind(
        gaps: gaps,
        incomplete: incomplete,
        conversation_date: conversation_date
      )

      Result.new(
        keystone_goals: goals,
        uncovered_blocking_gaps: gaps,
        path_rows: path_rows(gaps: gaps),
        conversation_date: conversation_date,
        prompt_kind: prompt_kind,
        employee_casual_name: employee_casual_name,
        manager_casual_name: manager_casual_name,
        target_equals_current: target_equals_current?,
        target_eligible: target_eligible
      )
    end

    private

    attr_reader :teammate, :target_position, :target_eligible, :eligibility_checks

    def empty_result
      Result.new(
        keystone_goals: [],
        uncovered_blocking_gaps: [],
        path_rows: [],
        conversation_date: nil,
        prompt_kind: PROMPT_INCOMPLETE_PATH,
        employee_casual_name: employee_casual_name,
        manager_casual_name: manager_casual_name,
        target_equals_current: false,
        target_eligible: false
      )
    end

    def employee_casual_name
      teammate.person&.casual_name.to_s.strip.presence || "the teammate"
    end

    def manager_casual_name
      teammate.current_manager&.casual_name.to_s.strip.presence || "their manager"
    end

    def current_position
      @current_position ||= teammate.active_employment_tenure&.position
    end

    def target_equals_current?
      current_position.present? && target_position.id == current_position.id
    end

    def required_assignment_ids
      @required_assignment_ids ||= target_position.required_assignments.pluck(:assignment_id).to_set
    end

    def required_ability_map
      @required_ability_map ||= MyGrowthAbilityMilestoneRows.structured_requirements_by_ability_id(target_position)
    end

    def wtm_keys
      @wtm_keys ||= begin
        keys = Set.new
        latest_assignment_check_ins.each_value do |check_in|
          next unless check_in.official_rating == "working_to_meet"

          keys << ["Assignment", check_in.assignment_id]
        end
        latest_aspiration_check_ins.each_value do |check_in|
          next unless check_in.official_rating == "working_to_meet"

          keys << ["Aspiration", check_in.aspiration_id]
        end
        keys
      end
    end

    def latest_assignment_check_ins
      @latest_assignment_check_ins ||= AssignmentCheckIn.latest_finalized_index_by(
        AssignmentCheckIn.where(company_teammate: teammate),
        :assignment_id
      )
    end

    def latest_aspiration_check_ins
      @latest_aspiration_check_ins ||= AspirationCheckIn.latest_finalized_index_by(
        AspirationCheckIn.where(company_teammate: teammate),
        :aspiration_id
      )
    end

    def earned_ability_levels
      @earned_ability_levels ||= begin
        ability_ids = required_ability_map.keys
        return {} if ability_ids.empty?

        TeammateMilestone
          .where(company_teammate: teammate, ability_id: ability_ids)
          .group(:ability_id)
          .maximum(:milestone_level)
      end
    end

    def goal_coverage_keys
      @goal_coverage_keys ||= begin
        keys = Set.new
        associations_for_owned_goals.each do |ga|
          keys << [ga.associable_type, ga.associable_id]
        end
        keys
      end
    end

    def associations_for_owned_goals
      @associations_for_owned_goals ||= GoalAssociation
        .joins(:goal)
        .where(
          goals: {
            owner_type: "CompanyTeammate",
            owner_id: teammate.id,
            deleted_at: nil
          }
        )
        .includes(:goal)
        .to_a
    end

    def goals_by_associable_key
      @goals_by_associable_key ||= begin
        hash = Hash.new { |h, k| h[k] = [] }
        associations_for_owned_goals.each do |ga|
          next unless keystone_association?(ga) || exceed_candidate_key?(ga.associable_type, ga.associable_id)
          next if ga.goal.blank?

          hash[[ga.associable_type, ga.associable_id]] << ga.goal
        end
        hash
      end
    end

    def keystone_goals
      goals_by_id = {}
      associations_for_owned_goals.each do |ga|
        next unless keystone_association?(ga)

        goal = ga.goal
        next if goal.blank?

        goals_by_id[goal.id] ||= goal
      end

      goals_by_id.values.sort_by { |g| [g.completed_at.present? ? 1 : 0, g.title.to_s.downcase] }
    end

    def keystone_association?(ga)
      case ga.associable_type
      when "Assignment"
        required_assignment_ids.include?(ga.associable_id) || wtm_keys.include?(["Assignment", ga.associable_id])
      when "Ability"
        required_ability_map.key?(ga.associable_id)
      when "Aspiration"
        wtm_keys.include?(["Aspiration", ga.associable_id])
      else
        false
      end
    end

    def uncovered_blocking_gaps
      gaps = []
      gaps.concat(uncovered_required_assignment_gaps)
      gaps.concat(uncovered_ability_gaps)
      gaps.sort_by { |g| [g.kind.to_s, g.label.to_s.downcase] }
    end

    def uncovered_required_assignment_gaps
      return [] if required_assignment_ids.empty?

      assignments = Assignment.where(id: required_assignment_ids.to_a).index_by(&:id)
      required_assignment_ids.filter_map do |assignment_id|
        next if goal_coverage_keys.include?(["Assignment", assignment_id])
        next if assignment_meeting_or_exceeding?(assignment_id)

        assignment = assignments[assignment_id]
        next unless assignment

        Gap.new(
          kind: :required_assignment,
          record: assignment,
          label: assignment.title,
          detail: "Required for the target position and not yet meeting expectations"
        )
      end
    end

    def assignment_meeting_or_exceeding?(assignment_id)
      rating = latest_assignment_check_ins[assignment_id]&.official_rating
      rating.in?(%w[meeting exceeding])
    end

    def uncovered_ability_gaps
      return [] if required_ability_map.empty?

      abilities = Ability.where(id: required_ability_map.keys).index_by(&:id)
      required_ability_map.filter_map do |ability_id, data|
        required_level = data[:minimum_milestone_level].to_i
        earned_level = earned_ability_levels[ability_id].to_i
        next unless required_level > earned_level
        next if goal_coverage_keys.include?(["Ability", ability_id])

        ability = abilities[ability_id]
        next unless ability

        Gap.new(
          kind: :ability_milestone,
          record: ability,
          label: ability.name,
          detail: "Milestone #{required_level} required (earned #{earned_level})"
        )
      end
    end

    def only_blocked_by_exceeding?
      return false if target_eligible
      return false if eligibility_checks.blank?

      failed = eligibility_checks.select { |check| check[:status] == :failed }
      return false if failed.empty?

      failed.all? { |check| exceed_only_failure?(check) }
    end

    def exceed_only_failure?(check)
      return false unless EXCEED_CHECK_KEYS.include?(check[:key])

      details = check[:details] || {}
      min_meeting = details[:minimum_percentage_meeting]
      min_exceeding = details[:minimum_percentage_exceeding]
      return false if min_exceeding.blank?

      pct_meeting = details[:qualifying_percentage_meeting].to_f
      pct_exceeding = details[:qualifying_percentage_exceeding].to_f
      meeting_ok = min_meeting.blank? || pct_meeting >= min_meeting.to_f
      exceeding_ok = pct_exceeding >= min_exceeding.to_f
      meeting_ok && !exceeding_ok
    end

    def checks_with_unmet_exceeding
      eligibility_checks.select do |check|
        next false unless EXCEED_CHECK_KEYS.include?(check[:key])

        details = check[:details] || {}
        min_exceeding = details[:minimum_percentage_exceeding]
        next false if min_exceeding.blank?

        details[:qualifying_percentage_exceeding].to_f < min_exceeding.to_f
      end
    end

    def exceed_candidate_records
      @exceed_candidate_records ||= begin
        records = []
        checks_with_unmet_exceeding.each do |check|
          records.concat(meeting_rated_records_for_check(check[:key]))
        end
        records.uniq
      end
    end

    def exceed_candidate_key?(associable_type, associable_id)
      exceed_candidate_records.any? { |r| r.class.name == associable_type && r.id == associable_id }
    end

    def meeting_rated_records_for_check(key)
      case key
      when :required_assignment_check_in_requirements
        target_position.required_assignments.filter_map do |pa|
          assignment = pa.assignment
          next unless assignment
          next unless latest_assignment_check_ins[assignment.id]&.official_rating == "meeting"

          assignment
        end
      when :unique_to_you_assignment_check_in_requirements
        unique_to_you_assignments.filter_map do |assignment|
          next unless latest_assignment_check_ins[assignment.id]&.official_rating == "meeting"

          assignment
        end
      when :company_aspirational_values_check_in_requirements
        company_aspirations.filter_map do |aspiration|
          next unless latest_aspiration_check_ins[aspiration.id]&.official_rating == "meeting"

          aspiration
        end
      else
        []
      end
    end

    def unique_to_you_assignments
      required_ids = required_assignment_ids
      teammate.assignment_tenures.active
        .where.not(assignment_id: required_ids.to_a)
        .includes(:assignment)
        .map(&:assignment)
        .compact
        .uniq
    end

    def company_aspirations
      company = target_position.company.root_company || target_position.company
      Aspiration.within_hierarchy(company).ordered.to_a
    end

    def path_rows(gaps:)
      rows_by_key = {}

      gaps.each do |gap|
        key = associable_key_for(gap.record)
        rows_by_key[key] = PathRow.new(
          record: gap.record,
          object_label: gap.label,
          object_type_label: object_type_label_for(gap.record),
          reason: gap.detail,
          goal: nil,
          goal_status: :none
        )
      end

      goals_by_associable_key.each do |(associable_type, associable_id), goals|
        key = [associable_type, associable_id]
        next if rows_by_key.key?(key)

        record = record_for(associable_type, associable_id)
        next unless record

        primary = primary_goal(goals)
        reason =
          if exceed_candidate_key?(associable_type, associable_id)
            EXCEED_REASON
          else
            reason_for_covered(associable_type, associable_id)
          end
        rows_by_key[key] = PathRow.new(
          record: record,
          object_label: object_label_for(record),
          object_type_label: object_type_label_for(record),
          reason: reason,
          goal: primary,
          goal_status: goal_status_for(primary)
        )
      end

      exceed_candidate_records.each do |record|
        key = associable_key_for(record)
        next if rows_by_key.key?(key)

        goals = goals_by_associable_key[key]
        primary = goals.present? ? primary_goal(goals) : nil
        rows_by_key[key] = PathRow.new(
          record: record,
          object_label: object_label_for(record),
          object_type_label: object_type_label_for(record),
          reason: EXCEED_REASON,
          goal: primary,
          goal_status: goal_status_for(primary)
        )
      end

      rows_by_key.values.sort_by { |row| [row.goal_status == :none ? 0 : 1, row.object_type_label, row.object_label.to_s.downcase] }
    end

    def associable_key_for(record)
      [record.class.name, record.id]
    end

    def record_for(associable_type, associable_id)
      case associable_type
      when "Assignment" then Assignment.find_by(id: associable_id)
      when "Ability" then Ability.find_by(id: associable_id)
      when "Aspiration" then Aspiration.find_by(id: associable_id)
      end
    end

    def object_label_for(record)
      case record
      when Assignment then record.title
      when Ability, Aspiration then record.name
      else record.to_s
      end
    end

    def object_type_label_for(record)
      case record
      when Assignment then "Assignment"
      when Ability then "Ability"
      when Aspiration then "Aspiration"
      else record.class.name
      end
    end

    def reason_for_covered(associable_type, associable_id)
      case associable_type
      when "Assignment"
        if required_assignment_ids.include?(associable_id)
          "Required for the target position"
        else
          "Working to meet expectations"
        end
      when "Ability"
        data = required_ability_map[associable_id]
        if data
          required_level = data[:minimum_milestone_level].to_i
          earned_level = earned_ability_levels[associable_id].to_i
          "Milestone #{required_level} required (earned #{earned_level})"
        else
          "Required ability for the target position"
        end
      when "Aspiration"
        "Working to meet expectations"
      else
        "Keystone path item"
      end
    end

    def primary_goal(goals)
      goals.find { |g| g.completed_at.nil? && g.started_at.present? } ||
        goals.find { |g| g.completed_at.nil? && g.started_at.blank? } ||
        goals.max_by { |g| g.completed_at || Time.zone.at(0) }
    end

    def goal_status_for(goal)
      return :none if goal.blank?
      return :completed if goal.completed_at.present?
      return :draft if goal.started_at.blank?

      :active
    end

    def derive_conversation_date(incomplete:, gaps:)
      return nil if only_blocked_by_exceeding?
      return nil if gaps.any?
      return nil if incomplete.any? { |g| g.most_likely_target_date.blank? }
      return nil if incomplete.empty?

      incomplete.map(&:most_likely_target_date).max
    end

    def derive_prompt_kind(gaps:, incomplete:, conversation_date:)
      if target_equals_current? && target_eligible
        return PROMPT_SUGGEST_DIFFERENT_TARGET
      end

      if gaps.any? || incomplete.any? { |g| g.most_likely_target_date.blank? }
        return PROMPT_INCOMPLETE_PATH
      end

      return PROMPT_NEEDS_EXCEED_GOALS if only_blocked_by_exceeding?

      if gaps.empty? && incomplete.empty?
        return PROMPT_READY_NOW
      end

      return PROMPT_SCHEDULED if conversation_date.present?

      PROMPT_INCOMPLETE_PATH
    end
  end
end
