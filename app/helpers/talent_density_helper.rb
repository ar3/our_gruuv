# frozen_string_literal: true

module TalentDensityHelper
  def talent_density_choice_card_class(choice, selected:)
    tone = choice[:tone]
    selected_bg = selected ? "bg-#{tone}-subtle" : ""
    "form-check border border-#{tone} rounded p-3 h-100 #{selected_bg}".squish
  end

  def talent_density_choice_title_class(choice)
    "d-block fw-semibold text-#{choice[:tone]}"
  end

  def talent_density_visible_to_sentence(teammates)
    names = Array(teammates).map { |teammate| teammate.person&.casual_name }.compact
    return "managers in this hierarchy and people with manage-employment (except this teammate)" if names.empty?

    case names.size
    when 1 then names.first
    when 2 then "#{names[0]} and #{names[1]}"
    else "#{names[0..-2].join(', ')}, and #{names[-1]}"
    end
  end

  def talent_density_teammate_context_sentence(row)
    parts = []
    seat_name = row[:tenure]&.seat&.display_name
    parts << "in the seat #{seat_name}" if seat_name.present?

    position_name = row[:tenure]&.position&.display_name
    parts << "with the title/position #{position_name}" if position_name.present?

    parts << "and their last overall status was #{talent_density_last_overall_status(row)}"
    parts.join(", ")
  end

  def talent_density_last_overall_status(row)
    finalized = row[:latest_finalized]
    status = if finalized
      "#{position_rating_display(finalized.official_rating)} on #{format_date_in_user_timezone(finalized.official_check_in_completed_at)}"
    else
      "not yet finalized"
    end

    open_check_in = row[:open_check_in]
    if open_check_in&.manager_completed?
      "#{status} (open manager rating: #{position_rating_display(open_check_in.manager_rating)})"
    else
      status
    end
  end

  def talent_density_excluded_casual_names(teammates)
    Array(teammates).filter_map { |teammate| teammate.person&.casual_name }.join(", ")
  end

  def talent_density_viz_filter_params(overrides = {})
    {
      manager_id: @current_manager_filter,
      scope: @scope,
      display: @display,
      matrix: @matrix,
      exclude_teammate_ids: @exclude_ids,
      applied: 1
    }.merge(overrides)
  end

  def talent_density_matrix_path(organization, overrides = {})
    params_hash = talent_density_viz_filter_params(overrides)
    case params_hash[:matrix].to_s
    when "guidance_matrix"
      guidance_matrix_organization_talent_density_path(organization, params_hash)
    when "assignment_rating_alignment"
      assignment_rating_alignment_organization_talent_density_path(organization, params_hash)
    when "stances"
      organization_talent_density_path(organization, params_hash)
    else
      visualization_organization_talent_density_path(organization, params_hash)
    end
  end

  def talent_density_tab_path(organization, tab, viz_params = {})
    case tab
    when :guidance_matrix
      guidance_matrix_organization_talent_density_path(organization, viz_params)
    when :assignment_rating_alignment
      assignment_rating_alignment_organization_talent_density_path(organization, viz_params)
    when :visualization
      visualization_organization_talent_density_path(organization, viz_params)
    else
      organization_talent_density_path(organization, viz_params)
    end
  end

  def talent_density_marker_popover(point)
    name = ERB::Util.html_escape(point.teammate.person.display_name)
    keeper = ERB::Util.html_escape(TalentDensity::Rubric.do_label(point.stance&.stance) || "Not yet")
    keeper_who = ERB::Util.html_escape(talent_density_stance_actor_name(point))
    keeper_when = ERB::Util.html_escape(talent_density_stance_recorded_on(point))
    rating = ERB::Util.html_escape(point.finalized ? position_rating_display(point.finalized.official_rating) : "Not yet finalized")
    rating_who = ERB::Util.html_escape(point.finalized&.finalized_by_teammate&.person&.casual_name.presence || "Unknown")
    rating_when = if point.finalized&.official_check_in_completed_at
      ERB::Util.html_escape(format_date_in_user_timezone(point.finalized.official_check_in_completed_at))
    else
      "Unknown"
    end

    <<~HTML.squish
      <div class="text-start">
        #{name}<br>
        Keeper: #{keeper}<br>
        Recorded by #{keeper_who} on #{keeper_when}<br>
        Last finalized position: #{rating}<br>
        Finalized by #{rating_who} on #{rating_when}
      </div>
    HTML
  end

  def talent_density_guidance_marker_popover(point)
    name = ERB::Util.html_escape(point.teammate.person.display_name)
    actual = ERB::Util.html_escape(point.finalized ? position_rating_display(point.finalized.official_rating) : "Not yet finalized")
    guidance = if point.guidance_rating
      ERB::Util.html_escape(position_rating_display(point.guidance_rating))
    else
      "Not computable"
    end
    source = point.summary&.show_inflight_rating_chart ? "in-flight ratings chart" : "finalized (official) ratings chart"

    <<~HTML.squish
      <div class="text-start">
        #{name}<br>
        Actual overall: #{actual}<br>
        Guidance: #{guidance}<br>
        Based on #{ERB::Util.html_escape(source)}
      </div>
    HTML
  end

  def talent_density_alignment_arrow_compared_to(agreement)
    case agreement
    when :mgr_final_same_emp_differed
      "employee"
    when :all_differed, :emp_mgr_same_final_differed, :emp_final_same_mgr_differed
      "manager"
    end
  end

  def talent_density_alignment_arrow_label(point)
    compared = talent_density_alignment_arrow_compared_to(point.agreement)
    return "No direction" if point.arrow.blank? || compared.blank?

    case point.arrow
    when :better
      "Final rated higher than #{compared}"
    when :worse
      "Final rated lower than #{compared}"
    else
      "No direction"
    end
  end

  def talent_density_alignment_marker_popover(point)
    name = ERB::Util.html_escape(point.teammate.person.display_name)
    assignment = ERB::Util.html_escape(point.assignment.title)
    emp = ERB::Util.html_escape(point.check_in.employee_rating.to_s.humanize)
    mgr = ERB::Util.html_escape(point.check_in.manager_rating.to_s.humanize)
    final = ERB::Util.html_escape(point.check_in.official_rating.to_s.humanize)
    column = ERB::Util.html_escape(
      TalentDensity::AssignmentRatingAlignmentQuery::COLUMN_LABELS[point.agreement] || "Incomplete"
    )
    arrow = ERB::Util.html_escape(talent_density_alignment_arrow_label(point))

    <<~HTML.squish
      <div class="text-start">
        #{name}<br>
        Assignment: #{assignment}<br>
        Employee: #{emp}<br>
        Manager: #{mgr}<br>
        Final: #{final}<br>
        Pattern: #{column}<br>
        Arrow: #{arrow}
      </div>
    HTML
  end

  def talent_density_alignment_marker_tone(agreement)
    case agreement
    when :all_same then "success"
    when :all_differed then "danger"
    when :emp_mgr_same_final_differed then "warning"
    when :emp_final_same_mgr_differed then "info"
    when :mgr_final_same_emp_differed then "primary"
    else "secondary"
    end
  end

  def talent_density_alignment_arrow_icon(point)
    label = talent_density_alignment_arrow_label(point)
    case point.arrow
    when :better
      content_tag(:i, "", class: "bi bi-arrow-up-short text-success", title: label, "aria-label": label)
    when :worse
      content_tag(:i, "", class: "bi bi-arrow-down-short text-danger", title: label, "aria-label": label)
    else
      "".html_safe
    end
  end

  def talent_density_stance_actor_name(point)
    return "Unknown" unless point.stance_version

    paper_trail_whodunnit_casual_name(point.stance_version)
  end

  def talent_density_stance_recorded_on(point)
    time = point.stance_version&.created_at || point.stance&.updated_at
    return "Unknown" unless time

    format_date_in_user_timezone(time)
  end
end
