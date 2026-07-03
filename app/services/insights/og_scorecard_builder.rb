# frozen_string_literal: true

module Insights
  # Weekly scorecard rows for Insights: OG Scorecard (metric metadata + per-week values).
  class OgScorecardBuilder
    def initialize(company:, week_starts:, chart_range:, thresholds_by_key: {}, teammate_ids: nil)
      @company = company
      @week_starts = week_starts
      @chart_range = chart_range
      @thresholds_by_key = thresholds_by_key
      @teammate_ids = teammate_ids
      @check_in_data = OgScorecard::CheckInDataPreloader.new(company, teammate_ids: teammate_ids).load
    end

    def call
      active_by_week = active_teammate_counts_by_week
      publishers_this_week_by_week, observees_this_week_by_week = observation_this_week_counts_by_week
      publishers_by_week, observees_by_week = observation_all_time_counts_by_week
      check_in_clarity = OgScorecard::CheckInClarityWeekCounts.call(
        company: company,
        week_starts: week_starts,
        preloaded_data: @check_in_data,
        teammate_ids: teammate_ids
      )
      goal_aspiration_by_week = OgScorecard::GoalsActiveAssociationWeekCounts.call(
        company: company,
        week_starts: week_starts,
        associable_type: :aspiration,
        teammate_ids: teammate_ids
      )
      goal_assignment_by_week = OgScorecard::GoalsActiveAssociationWeekCounts.call(
        company: company,
        week_starts: week_starts,
        associable_type: :assignment,
        teammate_ids: teammate_ids
      )
      milestone_counts = OgScorecard::MilestonesWeekCounts.call(
        company: company,
        week_starts: week_starts,
        teammate_ids: teammate_ids
      )
      goal_ability_by_week = OgScorecard::GoalsActiveAssociationWeekCounts.call(
        company: company,
        week_starts: week_starts,
        associable_type: :ability,
        teammate_ids: teammate_ids
      )
      goals_counts = OgScorecard::GoalsWeekCounts.call(
        company: company,
        week_starts: week_starts,
        teammate_ids: teammate_ids
      )
      gruuv_health_result = OgScorecard::GruuvHealthWeekCounts.call(
        company: company,
        week_starts: week_starts,
        teammate_ids: teammate_ids
      )

      groups = OgScorecard::MetricRegistry.grouped.map do |group|
        rows = group[:entries].filter_map do |entry|
          if entry.separator
            { separator: true }
          else
            counts = counts_for(
              entry.key,
              active_by_week: active_by_week,
              publishers_this_week_by_week: publishers_this_week_by_week,
              observees_this_week_by_week: observees_this_week_by_week,
              publishers_by_week: publishers_by_week,
              observees_by_week: observees_by_week,
              check_in_clarity: check_in_clarity,
              goal_aspiration_by_week: goal_aspiration_by_week,
              goal_assignment_by_week: goal_assignment_by_week,
              milestone_counts: milestone_counts,
              goal_ability_by_week: goal_ability_by_week,
              goals_counts: goals_counts,
              gruuv_health_counts: gruuv_health_result.counts
            )
            build_row(entry, counts, active_by_week)
          end
        end
        { title: group[:title], rows: rows }
      end

      { groups: groups, gruuv_health_backfill_enqueued: gruuv_health_result.backfill_enqueued }
    end

    private

    attr_reader :company, :week_starts, :chart_range, :thresholds_by_key, :teammate_ids

    def teammate_in_scope?(teammate_id)
      teammate_id.present? && (teammate_ids.nil? || teammate_ids.include?(teammate_id))
    end

    def counts_for(key, active_by_week:, publishers_this_week_by_week:, observees_this_week_by_week:, publishers_by_week:, observees_by_week:, check_in_clarity:, goal_aspiration_by_week:, goal_assignment_by_week:, milestone_counts:, goal_ability_by_week:, goals_counts:, gruuv_health_counts:)
      case key
      when 'active_teammates' then active_by_week
      when 'unique_ogo_publishers_this_week' then publishers_this_week_by_week
      when 'unique_ogo_publishers' then publishers_by_week
      when 'unique_ogo_observees_this_week' then observees_this_week_by_week
      when 'unique_ogo_observees' then observees_by_week
      when 'all_check_ins_clear' then check_in_clarity[:all_check_ins_clear]
      when 'all_check_ins_blurred' then check_in_clarity[:all_check_ins_blurred]
      when 'all_check_ins_obscured' then check_in_clarity[:all_check_ins_obscured]
      when 'active_goal_aspiration' then goal_aspiration_by_week
      when 'active_goal_assignment' then goal_assignment_by_week
      when 'unique_teammates_milestone_this_week' then milestone_counts[:unique_teammates_milestone_this_week]
      when 'milestones_earned_this_week' then milestone_counts[:milestones_earned_this_week]
      when 'unique_teammates_milestone_90_days' then milestone_counts[:unique_teammates_milestone_90_days]
      when 'milestones_earned_90_days' then milestone_counts[:milestones_earned_90_days]
      when 'active_goal_ability' then goal_ability_by_week
      when 'unique_teammates_active_goal' then goals_counts[:unique_teammates_active_goal]
      when 'unique_teammates_goal_check_in_this_week' then goals_counts[:unique_teammates_goal_check_in_this_week]
      when 'unique_teammates_completed_goal_90_days' then goals_counts[:unique_teammates_completed_goal_90_days]
      else
        if key.start_with?(OgScorecard::GruuvHealthWeekCounts::METRIC_KEY_PREFIX)
          gruuv_health_counts[key] || week_starts.index_with { 0 }
        else
          week_starts.index_with { 0 }
        end
      end
    end

    def build_row(entry, counts_by_week, active_by_week)
      threshold = thresholds_by_key[entry.key] || {}
      weekly_values = week_starts.map { |wk| counts_by_week[wk] || 0 }
      weekly_cell_statuses = week_starts.map.with_index do |wk, idx|
        OgScorecard::CellStatus.for(
          value: weekly_values[idx],
          yellow: threshold[:yellow],
          green: threshold[:green],
          direction: entry.direction,
          mode: threshold[:mode] || 'absolute',
          active_teammate_count: active_by_week[wk]
        )
      end

      {
        key: entry.key,
        label: entry.label,
        threshold_hint: entry.threshold_hint,
        direction: entry.direction,
        supports_percent: entry.supports_percent,
        yellow: threshold[:yellow],
        green: threshold[:green],
        threshold_mode: threshold[:mode] || 'absolute',
        yellow_display: format_threshold(threshold[:yellow], threshold[:mode]),
        green_display: format_threshold(threshold[:green], threshold[:mode]),
        six_week_avg: average_last_n(weekly_values, 6),
        weekly_values: weekly_values,
        weekly_cell_statuses: weekly_cell_statuses
      }
    end

    def format_threshold(value, mode)
      return nil if value.nil?

      if mode.to_s == 'percent'
        num = value.to_f
        formatted = num == num.to_i ? num.to_i.to_s : num.round(1).to_s
        "#{formatted}%"
      else
        num = value.to_f
        num == num.to_i ? num.to_i : num.round(1)
      end
    end

    def average_last_n(values, n)
      return nil if values.empty?

      tail = values.last(n)
      (tail.sum.to_f / tail.size).round(1)
    end

    def active_teammate_counts_by_week
      scope = CompanyTeammate.for_organization_hierarchy(company).where.not(first_employed_at: nil)
      scope = scope.where(id: teammate_ids) if teammate_ids
      rows = scope.pluck(:first_employed_at, :last_terminated_at)

      week_starts.index_with do |week_start|
        week_end_time = (week_start + 6.days).in_time_zone.end_of_day
        rows.count { |first_employed_at, last_terminated_at|
          employed_on_or_before?(first_employed_at, week_end_time) &&
            not_terminated_before?(last_terminated_at, week_end_time)
        }
      end
    end

    def employed_on_or_before?(first_employed_at, week_end_time)
      return false if first_employed_at.blank?

      first_employed_at.to_time.in_time_zone <= week_end_time
    end

    def not_terminated_before?(last_terminated_at, week_end_time)
      last_terminated_at.nil? || last_terminated_at.to_time.in_time_zone > week_end_time
    end

    def observation_this_week_counts_by_week
      publishers_by_week = week_starts.index_with { Set.new }
      observees_by_week = week_starts.index_with { Set.new }
      week_set = week_starts.to_set

      obs_scope = Observation
        .for_company(company)
        .not_soft_deleted
        .published
        .where(published_at: chart_range)

      obs_rows = obs_scope.pluck(:published_at, :observer_id)
      observer_person_ids = obs_rows.map(&:last).compact.uniq
      teammate_id_by_person_id = teammate_id_by_person(observer_person_ids)

      obs_rows.each do |published_at, observer_person_id|
        next if published_at.blank? || observer_person_id.blank?

        wk = week_key_for(published_at)
        next unless week_set.include?(wk)

        tid = teammate_id_by_person_id[observer_person_id]
        publishers_by_week[wk] << tid if teammate_in_scope?(tid)
      end

      observee_rows = Observee
        .joins(:observation)
        .merge(obs_scope)
        .pluck("observations.published_at", "observees.teammate_id")

      observee_rows.each do |published_at, teammate_id|
        next if published_at.blank? || teammate_id.blank?

        wk = week_key_for(published_at)
        next unless week_set.include?(wk)

        observees_by_week[wk] << teammate_id if teammate_in_scope?(teammate_id)
      end

      [
        publishers_by_week.transform_values(&:size),
        observees_by_week.transform_values(&:size)
      ]
    end

    def week_key_for(time)
      time.in_time_zone.to_date.beginning_of_week(:monday)
    end

    def observation_all_time_counts_by_week
      publishers_by_week = week_starts.index_with { Set.new }
      observees_by_week = week_starts.index_with { Set.new }
      return [publishers_by_week.transform_values(&:size), observees_by_week.transform_values(&:size)] if week_starts.empty?

      active_ids_by_week = week_starts.index_with { |week_start|
        active_teammate_ids_for_week(week_start + 6.days)
      }
      max_week_end = (week_starts.max + 6.days).in_time_zone.end_of_day

      obs_scope = Observation
        .for_company(company)
        .not_soft_deleted
        .published
        .where("published_at <= ?", max_week_end)

      obs_rows = obs_scope.pluck(:published_at, :observer_id)
      observer_person_ids = obs_rows.map(&:last).compact.uniq
      teammate_id_by_person_id = teammate_id_by_person(observer_person_ids)

      obs_rows.each do |published_at, observer_person_id|
        next if published_at.blank? || observer_person_id.blank?

        tid = teammate_id_by_person_id[observer_person_id]
        next unless teammate_in_scope?(tid)

        week_starts.each do |week_start|
          week_end = (week_start + 6.days).in_time_zone.end_of_day
          next if published_at > week_end
          next unless active_ids_by_week[week_start].include?(tid)

          publishers_by_week[week_start] << tid
        end
      end

      observee_rows = Observee
        .joins(:observation)
        .merge(obs_scope)
        .pluck("observations.published_at", "observees.teammate_id")

      observee_rows.each do |published_at, teammate_id|
        next if published_at.blank? || teammate_id.blank?
        next unless teammate_in_scope?(teammate_id)

        week_starts.each do |week_start|
          week_end = (week_start + 6.days).in_time_zone.end_of_day
          next if published_at > week_end
          next unless active_ids_by_week[week_start].include?(teammate_id)

          observees_by_week[week_start] << teammate_id
        end
      end

      [
        publishers_by_week.transform_values(&:size),
        observees_by_week.transform_values(&:size)
      ]
    end

    def active_teammate_ids_for_week(week_ending_on)
      EngagementHealth::WeeklyRollupTeammateScope.active_teammate_ids(
        organization: company,
        week_ending_on: week_ending_on,
        teammate_ids: teammate_ids
      )
    end

    def teammate_id_by_person(person_ids)
      return {} if person_ids.empty?

      CompanyTeammate
        .for_organization_hierarchy(company)
        .where(person_id: person_ids)
        .pluck(:person_id, :id)
        .group_by(&:first)
        .transform_values { |pairs| pairs.map(&:last).last }
    end
  end
end
