# frozen_string_literal: true

module SingleItemCheckInHelper
  BUCKET_EMOJI = {
    red: "‼️",
    yellow: "⚠️",
    green: "✅"
  }.freeze

  def single_item_check_in_bucket_emoji(bucket)
    BUCKET_EMOJI[bucket&.to_sym] || "‼️"
  end

  def single_item_check_in_item_url(organization, teammate, item)
    case item[:type]
    when :aspiration
      organization_teammate_aspiration_path(organization, teammate, item[:id])
    when :assignment
      organization_teammate_assignment_path(organization, teammate, item[:id])
    when :position
      position_check_in_organization_teammate_path(organization, teammate)
    else
      "#"
    end
  end

  # Returns only the finalization (third) line of the check-in sentence for prior check-ins table.
  def single_item_check_in_finalization_sentence(check_in, employee_name, sentence_type)
    return "" if check_in.blank?
    full = case sentence_type.to_sym
           when :position then format_position_check_in_sentences(check_in, employee_name)
           when :assignment then format_assignment_check_in_sentences(check_in, employee_name)
           when :aspiration then format_aspiration_check_in_sentences(check_in, employee_name)
           else ""
           end
    lines = full.to_s.split("\n")
    lines[2].to_s.strip
  end

  # Full sentence block (employee, manager, finalization) for expandable details.
  def single_item_check_in_full_sentences(check_in, employee_name, sentence_type)
    return "" if check_in.blank?
    case sentence_type.to_sym
    when :position then format_position_check_in_sentences(check_in, employee_name)
    when :assignment then format_assignment_check_in_sentences(check_in, employee_name)
    when :aspiration then format_aspiration_check_in_sentences(check_in, employee_name)
    else ""
    end
  end

  # Timespan for prior check-in row: "Started YYYY-MM-DD – Finalized YYYY-MM-DD"
  def single_item_check_in_timespan(check_in)
    return "" if check_in.blank?
    start_date = check_in.check_in_started_on
    end_date = check_in.official_check_in_completed_at&.to_date
    start_str = start_date ? start_date.strftime("%Y-%m-%d") : "—"
    end_str = end_date ? end_date.strftime("%Y-%m-%d") : "—"
    "Started #{start_str} – Finalized #{end_str}"
  end

  DEFINE_SECTION_LABELS = {
    assignment: "About this assignment",
    aspiration: "About this value",
    position: "About this position"
  }.freeze

  CHECK_IN_SECTION_LABEL = "Your check-in"
  RESEARCH_SECTION_LABEL = "Context for your rating"

  def single_item_check_in_define_section_label(check_in_type)
    DEFINE_SECTION_LABELS.fetch(check_in_type.to_sym)
  end

  def single_item_check_in_nav_initial_section(open_check_in:)
    open_check_in.present? ? "check-in" : "define"
  end

  # Primary phase links plus optional Research sub-anchors (id, label, icon).
  def single_item_check_in_section_nav_links(check_in_type:, research_sublinks: [])
    [
      { id: "define", label: single_item_check_in_define_section_label(check_in_type), icon: "bi-info-circle", primary: true },
      { id: "check-in", label: CHECK_IN_SECTION_LABEL, icon: "bi-pencil-square", primary: true },
      { id: "research", label: RESEARCH_SECTION_LABEL, icon: "bi-journal-text", primary: true },
      *research_sublinks.map { |link| link.merge(primary: false) }
    ]
  end
end
