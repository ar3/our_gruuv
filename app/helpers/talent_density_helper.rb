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
end
