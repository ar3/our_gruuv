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
    matrix = params_hash[:matrix].to_s
    if matrix == "guidance_matrix"
      guidance_matrix_organization_talent_density_path(organization, params_hash)
    else
      visualization_organization_talent_density_path(organization, params_hash)
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
