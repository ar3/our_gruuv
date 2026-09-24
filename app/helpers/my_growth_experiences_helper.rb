# frozen_string_literal: true

module MyGrowthExperiencesHelper
  include AssociableGoalsHelper

  MY_GROWTH_SHARED_QUERY_KEYS = %w[show_suggested anchor].freeze

  def my_growth_shared_return_path_options
    return {} unless respond_to?(:request) && request&.query_parameters

    request.query_parameters.slice(*MY_GROWTH_SHARED_QUERY_KEYS).symbolize_keys
  end

  def my_growth_experiences_return_path_options
    my_growth_shared_return_path_options
  end

  def my_growth_experiences_return_url(organization, teammate)
    my_growth_experiences_organization_company_teammate_path(
      organization,
      teammate,
      **my_growth_shared_return_path_options
    )
  end

  def my_growth_abilities_return_url(organization, teammate)
    my_growth_abilities_organization_company_teammate_path(
      organization,
      teammate,
      **my_growth_shared_return_path_options
    )
  end

  def my_growth_complete_picture_return_url(organization, teammate)
    complete_picture_organization_company_teammate_path(
      organization,
      teammate,
      **my_growth_shared_return_path_options
    )
  end

  def my_growth_observation_new_for_associable_path(organization, teammate, associable, return_url:, return_text:)
    new_organization_observation_path(
      organization,
      observee_ids: [teammate.id],
      rateable_type: associable.class.name,
      rateable_id: associable.id,
      return_url: return_url,
      return_text: return_text
    )
  end

  def my_growth_goal_flow_allowed_for_associable?(associable, teammate)
    GoalFlowTeammateScope.teammate_matches_associable?(associable, teammate) &&
      policy(teammate).audit?
  end

  def my_growth_goal_flow_denied_tooltip
    'You need access as this teammate, their manager, or an employment administrator to set or link goals here.'
  end

  MY_GROWTH_CATALOG_GOALS_POPOVER_LIMIT = 5

  def my_growth_catalog_goal_button_label(casual_name:, associable:, open_count:)
    title = associable_display_title(associable)
    if open_count.zero?
      "Set goal for #{casual_name} & #{title}"
    else
      goals_phrase = "#{open_count} #{open_count == 1 ? 'active goal' : 'active goals'}"
      "Add to the #{goals_phrase} for #{casual_name} & #{title}"
    end
  end

  def my_growth_catalog_goal_action_data(associable:, open_goals:, extra_footer: nil)
    base = { turbo: false }
    return base if open_goals.blank?

    base.merge(
      bs_toggle: "popover",
      bs_trigger: "hover focus",
      bs_placement: "top",
      bs_html: true,
      bs_custom_class: "text-start",
      bs_title: "Active goals",
      bs_content: my_growth_catalog_goals_popover_html(
        associable: associable,
        open_goals: open_goals,
        extra_footer: extra_footer
      )
    )
  end

  # Grow by Goals → Missing Goals: "N active goal(s)" badge with hover popover of goal titles.
  def missing_goals_active_goals_badge(associable:, active_goals:, count: nil)
    goals = Array(active_goals)
    count = (count.nil? ? goals.size : count).to_i
    label = pluralize(count, "active goal")
    return content_tag(:span, label, class: "badge text-bg-success") if goals.blank?

    content_tag(
      :span,
      label,
      class: "badge text-bg-success",
      tabindex: 0,
      role: "button",
      "aria-label": label,
      data: {
        bs_toggle: "popover",
        bs_trigger: "hover focus",
        bs_placement: "top",
        bs_html: true,
        bs_custom_class: "text-start",
        bs_title: "Active goals",
        bs_content: my_growth_catalog_goals_popover_html(associable: associable, open_goals: goals)
      }
    )
  end

  def teammate_draft_goals_index_path(organization, teammate, return_url: nil, return_text: nil)
    organization_goals_path(
      organization,
      owner_id: "CompanyTeammate_#{teammate.id}",
      status: "draft",
      view: "hierarchical-collapsible",
      return_url: return_url,
      return_text: return_text
    )
  end

  def my_growth_catalog_goals_popover_html(associable:, open_goals:, extra_footer: nil)
    return "".html_safe if open_goals.blank?

    object_name = associable_display_title(associable)
    shown = open_goals.first(MY_GROWTH_CATALOG_GOALS_POPOVER_LIMIT)
    list_items = shown.map do |goal_row|
      content_tag(:li, my_growth_catalog_goal_popover_line(goal_row))
    end
    list = content_tag(:ul, safe_join(list_items), class: "mb-2 ps-3")
    footer_class = extra_footer.present? ? "mb-2 small text-muted" : "mb-0 small text-muted"
    footer = content_tag(
      :p,
      "to see all of the goals, click on the #{object_name} name link above",
      class: footer_class
    )
    parts = [list, footer]
    if extra_footer.present?
      parts << content_tag(:p, extra_footer, class: "mb-0 small text-muted")
    end
    safe_join(parts)
  end

  def my_growth_catalog_goal_popover_line(goal_row)
    title = ERB::Util.html_escape(goal_row[:title].to_s)
    percentage = goal_row[:confidence_percentage]
    saved_at = goal_row[:confidence_saved_at]

    if percentage.present? && saved_at.present?
      date = format_date_in_user_timezone(saved_at, format: "%b %d, %Y")
      "#{title} — #{percentage}% as of #{ERB::Util.html_escape(date)}".html_safe
    else
      "#{title} — no confidence yet".html_safe
    end
  end

  def can_link_to_assignment_tenure_bypass?(teammate, organization)
    viewing = current_company_teammate
    return false unless viewing

    has_manage_employment = policy(organization).manage_employment?
    return has_manage_employment if viewing == teammate

    viewing.in_managerial_hierarchy_of?(teammate) || has_manage_employment
  end

  def my_growth_experiences_summary_alert_class(summary)
    case summary.alert_band
    when :success then 'alert-success'
    when :warning then 'alert-warning'
    else 'alert-danger'
    end
  end

  def my_growth_experiences_summary_alert_html(summary, teammate, organization)
    total = summary.total_energy_percentage
    casual = ERB::Util.html_escape(teammate.person.casual_name.presence || 'this teammate')

    case summary.alert_band
    when :success
      safe_join([
        "#{casual}'s assignments add up to #{total}% of the energy they are allocating 🎉. ",
        'This does not mean 100% of everything they are doing is captured perfectly—it does mean ',
        'the major things we need should have clear expectations on are logged.'
      ])
    when :warning
      safe_join([
        "#{casual}'s assignments add up to #{total}% of allocated energy—close to 100%. ",
        'For clearer expectations across day-to-day work, ',
        my_growth_experiences_bypass_allocation_fragment(teammate, organization),
        '.'
      ])
    else
      safe_join([
        "#{casual}'s assignments add up to #{total}% of allocated energy, which may signal a lack of clarity ",
        'about where their energy goes. ',
        my_growth_experiences_bypass_allocation_fragment(teammate, organization, leading_capitalize: true),
        '.'
      ])
    end
  end

  def my_growth_experiences_bypass_allocation_fragment(teammate, organization, leading_capitalize: false)
    if can_link_to_assignment_tenure_bypass?(teammate, organization)
      link_to(
        "adjust energy allocation on the #{set_day_to_day_assignments_label} page",
        assignment_tenure_check_in_bypass_organization_company_teammate_path(organization, teammate),
        class: 'alert-link'
      )
    else
      text = 'ask someone in your managerial hierarchy or with employment administration access to adjust energy ' \
             "allocation on the #{set_day_to_day_assignments_label} page"
      leading_capitalize ? text.capitalize : text
    end
  end
end
