# frozen_string_literal: true

module ProtectFlow
  # Builds a manager's Protect Flow plan from Engagement Health category rollups.
  # Progress is current (or week-end) vs week-start snapshot — never manual checkoffs.
  class PlanBuilder
    include Rails.application.routes.url_helpers

    CATEGORY_PRIORITY = [
      EngagementHealth::CATEGORY_REQUIRED_CLARITY,
      EngagementHealth::CATEGORY_MILESTONES,
      EngagementHealth::CATEGORY_GOAL_CONFIDENCE,
      EngagementHealth::CATEGORY_OGO_GIVEN,
      EngagementHealth::CATEGORY_OGO_RECEIVED
    ].freeze

    CATEGORY_FLOW_ROLE = {
      EngagementHealth::CATEGORY_REQUIRED_CLARITY => "clarity of purpose",
      EngagementHealth::CATEGORY_MILESTONES => "proper challenge",
      EngagementHealth::CATEGORY_GOAL_CONFIDENCE => "proper challenge",
      EngagementHealth::CATEGORY_OGO_GIVEN => "continuous feedback",
      EngagementHealth::CATEGORY_OGO_RECEIVED => "continuous feedback"
    }.freeze

    CATEGORY_SHORT_LABELS = {
      EngagementHealth::CATEGORY_REQUIRED_CLARITY => "Clarity Check-ins",
      EngagementHealth::CATEGORY_MILESTONES => "Milestones",
      EngagementHealth::CATEGORY_GOAL_CONFIDENCE => "Goal Confidence",
      EngagementHealth::CATEGORY_OGO_GIVEN => "OGOs Given",
      EngagementHealth::CATEGORY_OGO_RECEIVED => "OGOs Received"
    }.freeze

    def self.call(...) = new(...).call

    def initialize(organization:, week_store:, teammates:, week_start: nil)
      @organization = organization
      @week_store = week_store
      @teammates = Array(teammates)
      @requested_week_start = week_start.presence
    end

    def call
      reports = sorted_teammates
      live_rollups = load_category_rollups(reports.map(&:id))
      live_baseline = baseline_from_rollups(reports, live_rollups)

      current_week = @week_store.ensure_current_week!(live_baseline: live_baseline)
      available_weeks = @week_store.available_weeks

      viewing_week =
        if @requested_week_start.present? && @requested_week_start != current_week[:week_start]
          @week_store.find_week(@requested_week_start) || current_week
        else
          current_week
        end

      historical = viewing_week[:week_start] != current_week[:week_start] || viewing_week[:closed]
      # Current open week compares live EH to start; closed weeks compare end to start.
      comparison_baseline =
        if historical && viewing_week[:end_baseline].present?
          viewing_week[:end_baseline]
        elsif historical && viewing_week[:week_start] != current_week[:week_start]
          viewing_week[:start_baseline]
        else
          live_baseline
        end

      start_baseline = viewing_week[:start_baseline]

      people = reports.map do |teammate|
        build_person(
          teammate,
          current_statuses: statuses_from_baseline(comparison_baseline, teammate.id, live_rollups[teammate.id]),
          start_statuses: start_baseline[teammate.id.to_s] || {}
        )
      end
      people = sort_people(people)
      item_links_by_teammate = HeroItemLinks.for_people(organization: @organization, people: people)
      people = people.map do |person|
        person.merge(hero_item_links: item_links_by_teammate[person[:teammate_id]] || [])
      end

      {
        week_start: viewing_week[:week_start],
        current_week_start: current_week[:week_start],
        historical: historical && viewing_week[:week_start] != current_week[:week_start],
        week_closed: viewing_week[:closed],
        available_weeks: available_weeks,
        people: people,
        progress: build_progress(people, start_baseline, comparison_baseline)
      }
    end

    private

    def company
      @company ||= @organization.root_company || @organization
    end

    def sorted_teammates
      @teammates.sort_by { |tm| tm.person.casual_name.to_s.downcase }
    end

    def load_category_rollups(teammate_ids)
      return {} if teammate_ids.empty?

      EngagementHealthStatus
        .category_rollups
        .where(organization: @organization, teammate_id: teammate_ids)
        .group_by(&:teammate_id)
        .transform_values { |rows| rows.index_by(&:category) }
    end

    def baseline_from_rollups(reports, rollups_by_teammate)
      reports.each_with_object({}) do |teammate, hash|
        rows = rollups_by_teammate[teammate.id] || {}
        next if rows.blank?

        hash[teammate.id.to_s] = CATEGORY_PRIORITY.each_with_object({}) do |category, cats|
          row = rows[category]
          cats[category] = row&.status || EngagementHealth::WARNING
        end
      end
    end

    def statuses_from_baseline(baseline, teammate_id, live_rows)
      from_snap = baseline[teammate_id.to_s]
      if from_snap.present?
        return CATEGORY_PRIORITY.map do |category|
          status = from_snap[category] || EngagementHealth::WARNING
          status_row(category, status)
        end
      end

      return nil if live_rows.blank?

      CATEGORY_PRIORITY.map do |category|
        status = live_rows[category]&.status || EngagementHealth::WARNING
        status_row(category, status)
      end
    end

    def status_row(category, status)
      {
        category: category,
        status: status,
        label: EngagementHealth::CATEGORY_LABELS.fetch(category),
        short_title: CATEGORY_SHORT_LABELS.fetch(category),
        flow_role: CATEGORY_FLOW_ROLE.fetch(category),
        severity: EngagementHealth.status_severity_rank(status)
      }
    end

    def build_person(teammate, current_statuses:, start_statuses:)
      if current_statuses.blank?
        return pending_health_person(teammate, start_statuses)
      end

      enriched = current_statuses.map do |row|
        start_status = start_statuses[row[:category]]
        improved = start_status.present? &&
          EngagementHealth.status_severity_rank(row[:status]) > EngagementHealth.status_severity_rank(start_status)
        cleared = improved && row[:status] == EngagementHealth::HEALTHY
        row.merge(
          start_status: start_status,
          improved: improved,
          cleared: cleared
        )
      end

      unhealthy = enriched
        .reject { |s| s[:status] == EngagementHealth::HEALTHY }
        .sort_by { |s| [s[:severity], CATEGORY_PRIORITY.index(s[:category])] }

      healthy = enriched.select { |s| s[:status] == EngagementHealth::HEALTHY }

      hero, secondary =
        if unhealthy.any?
          [action_for(teammate, unhealthy.first, role: :hero), unhealthy.drop(1).map { |s| action_for(teammate, s, role: :secondary) }]
        else
          [healthy_maintain_action(teammate), []]
        end

      clear_items = healthy.map { |row| clear_item_for(teammate, row) }

      worst = EngagementHealth.worst_status(enriched.map { |s| s[:status] })
      start_unhealthy = start_statuses.count { |_c, s| s.present? && s != EngagementHealth::HEALTHY }
      current_unhealthy = enriched.count { |s| s[:status] != EngagementHealth::HEALTHY }

      {
        teammate: teammate,
        teammate_id: teammate.id,
        name: teammate.person.casual_name,
        hub_path: organization_company_teammate_one_on_one_link_path(@organization, teammate),
        statuses: enriched,
        worst_status: worst,
        urgency_rank: EngagementHealth.status_severity_rank(worst),
        unhealthy_count: current_unhealthy,
        start_unhealthy_count: start_unhealthy,
        hero: hero,
        secondary: secondary,
        clear_items: clear_items
      }
    end

    def pending_health_person(teammate, start_statuses)
      hero = {
        role: :hero,
        category: "pending_health",
        status: EngagementHealth::WARNING,
        status_label: "Pending",
        short_title: "Health pending",
        title: "Health pending",
        why: "Engagement Health has not been calculated yet for this person. #{one_thing_label_for_teammate(teammate)} loads live signals so you can protect flow.",
        cta_label: "Open #{one_thing_label_for_teammate(teammate)}",
        path: organization_company_teammate_one_on_one_link_path(@organization, teammate),
        cleared: false
      }
      {
        teammate: teammate,
        teammate_id: teammate.id,
        name: teammate.person.casual_name,
        hub_path: organization_company_teammate_one_on_one_link_path(@organization, teammate),
        statuses: [],
        worst_status: EngagementHealth::WARNING,
        urgency_rank: EngagementHealth.status_severity_rank(EngagementHealth::WARNING),
        unhealthy_count: 0,
        start_unhealthy_count: start_statuses.count { |_c, s| s.present? && s != EngagementHealth::HEALTHY },
        hero: hero,
        secondary: [],
        clear_items: []
      }
    end

    def action_for(teammate, status_row, role:)
      category = status_row[:category]
      short = CATEGORY_SHORT_LABELS.fetch(category)
      {
        role: role,
        category: category,
        status: status_row[:status],
        status_label: EngagementHealth::STATUS_LABELS.fetch(status_row[:status]),
        short_title: short,
        title: short,
        why: action_why(category, role),
        cta_label: action_cta_label(teammate, category),
        path: action_path(teammate, category),
        cleared: false,
        improved: status_row[:improved]
      }
    end

    def clear_item_for(teammate, status_row)
      category = status_row[:category]
      short = CATEGORY_SHORT_LABELS.fetch(category)
      {
        role: :clear,
        category: category,
        status: status_row[:status],
        status_label: EngagementHealth::STATUS_LABELS.fetch(status_row[:status]),
        short_title: short,
        title: short,
        why: action_why(category, :clear),
        cta_label: action_cta_label(teammate, category),
        path: action_path(teammate, category),
        cleared: status_row[:cleared],
        start_status: status_row[:start_status],
        improved: status_row[:improved]
      }
    end

    def healthy_maintain_action(teammate)
      {
        role: :hero,
        category: "maintain",
        status: EngagementHealth::HEALTHY,
        status_label: EngagementHealth::STATUS_LABELS.fetch(EngagementHealth::HEALTHY),
        short_title: "Stay clear",
        title: "Stay clear",
        why: "They're healthy across vectors. A short 1:1 still protects flow before signals go stale.",
        cta_label: "Open #{one_thing_label_for_teammate(teammate)}",
        path: organization_company_teammate_one_on_one_link_path(@organization, teammate),
        cleared: false
      }
    end

    def action_why(category, role)
      flow_role = CATEGORY_FLOW_ROLE.fetch(category)
      base = "Flow needs #{flow_role}. Stale #{EngagementHealth::CATEGORY_LABELS.fetch(category).downcase} erodes clarity of where they stand."
      case role
      when :hero
        base
      when :clear
        "#{base} This vector is healthy — keep it that way."
      else
        "#{base} Secondary to the highest-leverage move for this person — still part of protecting flow."
      end
    end

    def action_cta_label(teammate, category)
      case category
      when EngagementHealth::CATEGORY_REQUIRED_CLARITY then "Open Clarity Check-ins"
      when EngagementHealth::CATEGORY_MILESTONES then "Review ability milestones"
      when EngagementHealth::CATEGORY_GOAL_CONFIDENCE then "Open goals"
      when EngagementHealth::CATEGORY_OGO_GIVEN then "Coach OGOs given"
      when EngagementHealth::CATEGORY_OGO_RECEIVED then "Give or review OGOs"
      else "Open #{one_thing_label_for_teammate(teammate)}"
      end
    end

    def action_path(teammate, category)
      case category
      when EngagementHealth::CATEGORY_REQUIRED_CLARITY
        up_next_organization_company_teammate_check_ins_path(@organization, teammate)
      when EngagementHealth::CATEGORY_MILESTONES
        my_growth_abilities_organization_company_teammate_path(@organization, teammate)
      when EngagementHealth::CATEGORY_GOAL_CONFIDENCE
        my_growth_goals_organization_company_teammate_path(@organization, teammate)
      when EngagementHealth::CATEGORY_OGO_GIVEN
        ogos_from_organization_company_teammate_path(@organization, teammate)
      when EngagementHealth::CATEGORY_OGO_RECEIVED
        ogos_organization_company_teammate_path(@organization, teammate)
      else
        organization_company_teammate_one_on_one_link_path(@organization, teammate)
      end
    end

    def sort_people(people)
      people.sort_by { |p| [p[:urgency_rank], -p[:unhealthy_count], p[:name].to_s.downcase] }
    end

    def build_progress(people, start_baseline, comparison_baseline)
      start_unhealthy = count_unhealthy_in_baseline(start_baseline)
      current_unhealthy = count_unhealthy_in_baseline(comparison_baseline)
      improved = count_improved(start_baseline, comparison_baseline)

      {
        start_unhealthy_count: start_unhealthy,
        current_unhealthy_count: current_unhealthy,
        improved_vector_count: improved,
        people_count: people.size,
        healthy_people_count: people.count { |p| p[:worst_status] == EngagementHealth::HEALTHY }
      }
    end

    def count_unhealthy_in_baseline(baseline)
      return 0 if baseline.blank?

      baseline.values.sum do |cats|
        next 0 unless cats.is_a?(Hash)

        cats.count { |_c, status| status.present? && status != EngagementHealth::HEALTHY }
      end
    end

    def count_improved(start_baseline, comparison_baseline)
      return 0 if start_baseline.blank? || comparison_baseline.blank?

      start_baseline.sum do |teammate_id, cats|
        current = comparison_baseline[teammate_id] || {}
        next 0 unless cats.is_a?(Hash)

        cats.count do |category, prior|
          now = current[category]
          next false if prior.blank? || now.blank?

          EngagementHealth.status_severity_rank(now) > EngagementHealth.status_severity_rank(prior)
        end
      end
    end
  end
end
