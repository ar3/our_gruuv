# frozen_string_literal: true

module Organizations
  module OneOnOneLinksHelper
    def one_on_one_hub_work_to_meet_tab_badge(summary)
      variant = summary.tab_variant
      count = summary.tab_count
      css =
        case variant
        when :danger then "badge rounded-pill text-bg-danger ms-2"
        when :info then "badge rounded-pill text-bg-info ms-2"
        else "badge rounded-pill text-bg-success ms-2"
        end

      content_tag(:span, count, class: css, aria: { label: work_to_meet_tab_badge_aria_label(variant, count) })
    end

    def engagement_health_status_badge(status, size: nil)
      css =
        case status
        when EngagementHealth::HEALTHY then "badge text-bg-success"
        when EngagementHealth::WARNING then "badge text-bg-warning"
        when EngagementHealth::NEEDS_ATTENTION then "badge text-bg-danger"
        else "badge text-bg-secondary"
        end
      css += " fs-6" if size == :lg

      content_tag(:span, EngagementHealth::STATUS_LABELS.fetch(status, status.to_s.humanize), class: css)
    end

    def engagement_health_category_label(category)
      EngagementHealth::CATEGORY_LABELS.fetch(category, category.to_s.humanize)
    end

    def engagement_health_section_anchor(category)
      "engagement-health-#{category.to_s.dasherize}"
    end

    # Worst status first, then alphanumeric by item name.
    def engagement_health_sorted_items(items)
      items.sort_by do |item|
        [EngagementHealth.status_severity_rank(item.status), item.inputs["name"].to_s.downcase]
      end
    end

    # Item name linked to the most appropriate page for that entity.
    def engagement_health_item_link(item)
      name = item.inputs["name"]
      path = engagement_health_item_path(item)
      path ? link_to(name, path) : name
    end

    def engagement_health_item_path(item)
      case item.category
      when EngagementHealth::CATEGORY_OGO_GIVEN
        ogos_from_organization_company_teammate_path(organization, teammate_route_param(@teammate))
      when EngagementHealth::CATEGORY_OGO_RECEIVED
        ogos_organization_company_teammate_path(organization, teammate_route_param(@teammate))
      when EngagementHealth::CATEGORY_GOAL_CONFIDENCE
        organization_goal_path(organization, item.entity_id)
      when EngagementHealth::CATEGORY_REQUIRED_CLARITY
        case item.entity_type
        when "Position" then organization_teammate_position_path(organization, @teammate)
        when "Assignment" then organization_teammate_assignment_path(organization, @teammate, item.entity_id)
        when "Aspiration" then organization_teammate_aspiration_path(organization, @teammate, item.entity_id)
        end
      when EngagementHealth::CATEGORY_MILESTONES
        organization_teammate_ability_path(organization, @teammate, item.entity_id)
      end
    end

    # Linked event summary plus "N days ago" in words; the exact timestamp
    # (in the viewer's timezone) lives in a hover tooltip.
    def engagement_health_last_event_display(item)
      inputs = item.inputs
      return content_tag(:span, "Never", class: "badge text-bg-danger") if inputs["never"]

      last_event_at = inputs["last_event_at"]
      return "—" if last_event_at.blank?

      time = Time.zone.parse(last_event_at)
      label = inputs["last_event_summary"].presence || format_date_in_user_timezone(time)
      path = engagement_health_event_path(item)
      event = path ? link_to(label, path) : label

      days_ago = content_tag(
        :span,
        "#{time_ago_in_words(time)} ago",
        class: "text-muted text-nowrap small",
        data: { bs_toggle: "tooltip", bs_placement: "top" },
        title: format_time_in_user_timezone(time)
      )

      safe_join([event, days_ago], " · ")
    end

    def engagement_health_event_path(item)
      case item.inputs["last_event_type"]
      when "Observation"
        organization_observation_path(organization, item.inputs["last_event_id"])
      when "GoalCheckIn"
        organization_goal_path(organization, item.entity_id, anchor: "check-in")
      when "PositionCheckIn", "AssignmentCheckIn", "AspirationCheckIn"
        engagement_health_item_path(item)
      end
    end

    def engagement_health_section_help(category, casual_name)
      case category
      when EngagementHealth::CATEGORY_OGO_GIVEN
        "Tracks the most recent published OGO #{casual_name} gave to anyone. " \
          "Healthy when the last one is #{EngagementHealth::Thresholds::OGO_HEALTHY_WITHIN_DAYS} days old or less, " \
          "Needs Attention at #{EngagementHealth::Thresholds::OGO_NEEDS_ATTENTION_AT_DAYS}+ days or if none was ever given; Warning in between."
      when EngagementHealth::CATEGORY_OGO_RECEIVED
        "Tracks the most recent published OGO anyone gave about #{casual_name}. " \
          "Healthy when the last one is #{EngagementHealth::Thresholds::OGO_HEALTHY_WITHIN_DAYS} days old or less, " \
          "Needs Attention at #{EngagementHealth::Thresholds::OGO_NEEDS_ATTENTION_AT_DAYS}+ days or if none was ever received; Warning in between."
      when EngagementHealth::CATEGORY_GOAL_CONFIDENCE
        "Each started goal (plus goals completed in the last #{EngagementHealth::Thresholds::COMPLETED_GOAL_WINDOW_DAYS} days) is rated by its most recent confidence check. " \
          "Healthy when checked within #{EngagementHealth::Thresholds::GOAL_CONFIDENCE_HEALTHY_WITHIN_DAYS} days, " \
          "Needs Attention at #{EngagementHealth::Thresholds::GOAL_CONFIDENCE_NEEDS_ATTENTION_AT_DAYS}+ days or never; Warning in between. " \
          "Never having started or completed a goal is itself Needs Attention."
      when EngagementHealth::CATEGORY_REQUIRED_CLARITY
        "Each required check-in item (current position, required and actively-tenured assignments, and aspirations) is rated by its last finalized check-in. " \
          "These are required, so the thresholds are stricter: Healthy when finalized within #{EngagementHealth::Thresholds::REQUIRED_CLARITY_HEALTHY_WITHIN_DAYS} days, " \
          "Needs Attention at #{EngagementHealth::Thresholds::REQUIRED_CLARITY_NEEDS_ATTENTION_AT_DAYS}+ days or never; Warning in between."
      when EngagementHealth::CATEGORY_MILESTONES
        "Each ability required by #{casual_name}'s position or assignments is rated at its highest required milestone level. " \
          "Healthy when the required level is earned or an active goal is attached to the ability; " \
          "Warning when an earlier milestone is earned or only a draft goal is attached; " \
          "Needs Attention when there is no milestone and no goal."
      end
    end

    def work_to_meet_return_url
      work_to_meet_organization_company_teammate_one_on_one_link_path(organization, teammate_route_param(@teammate))
    end

    def work_to_meet_add_goal_path(associable)
      case associable
      when Assignment
        choose_manage_goals_organization_assignment_path(
          organization,
          associable,
          return_url: work_to_meet_return_url,
          return_text: "Back to Work to Meet",
          for_company_teammate_id: @teammate.id
        )
      when Aspiration
        choose_manage_goals_organization_aspiration_path(
          organization,
          associable,
          return_url: work_to_meet_return_url,
          return_text: "Back to Work to Meet",
          for_company_teammate_id: @teammate.id
        )
      end
    end

    def work_to_meet_teammate_lens_path(associable)
      case associable
      when Assignment
        organization_teammate_assignment_path(organization, @teammate, associable)
      when Aspiration
        organization_teammate_aspiration_path(organization, @teammate, associable)
      end
    end

    def work_to_meet_draft_goals_path
      organization_goals_path(
        organization,
        owner_id: "CompanyTeammate_#{@teammate.id}",
        status: "draft",
        view: "hierarchical-collapsible",
        return_url: work_to_meet_return_url,
        return_text: "Back to Work to Meet"
      )
    end

    def work_to_meet_add_ogo_path(associable)
      new_quick_note_organization_observations_path(
        organization,
        observee_ids: [@teammate.id],
        rateable_type: associable.class.name,
        rateable_id: associable.id,
        return_url: work_to_meet_return_url,
        return_text: "Back to Work to Meet"
      )
    end

    def work_to_meet_filtered_ogos_path(associable)
      organization_observations_path(
        organization,
        observee_ids: [@teammate.id],
        rateable_type: associable.class.name,
        rateable_id: associable.id,
        return_url: work_to_meet_return_url,
        return_text: "Back to Work to Meet"
      )
    end

    def work_to_meet_ogo_count_caption_for(row)
      link_to pluralize(row.ogo_count, "relevant OGO"),
        work_to_meet_filtered_ogos_path(row.associable),
        class: "text-muted text-decoration-none"
    end

    private

    def work_to_meet_tab_badge_aria_label(variant, count)
      case variant
      when :danger
        "#{count} working-to-meet #{'area'.pluralize(count)} missing an active goal"
      when :info
        "#{count} working-to-meet #{'area'.pluralize(count)}, all with active goals"
      else
        "No essential working-to-meet areas"
      end
    end
  end
end
