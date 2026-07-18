# frozen_string_literal: true

module SingleItemCheckInHelper
  BUCKET_EMOJI = {
    red: "‼️",
    yellow: "⚠️",
    green: "✅"
  }.freeze

  VIEWER_STATE_CHIP_LABELS = {
    your_turn: "Your turn",
    waiting: "Waiting",
    review_together: "Review together",
    clear: "Clear"
  }.freeze

  def single_item_check_in_bucket_emoji(bucket)
    BUCKET_EMOJI[bucket&.to_sym] || "‼️"
  end

  def single_item_object_queue
    return @single_item_object_queue if defined?(@single_item_object_queue) && @single_item_object_queue

    @single_item_object_queue = CheckIns::SingleItemObjectQueueService.call(
      items: @single_item_ordered_items,
      engagement_health_records: @engagement_health_records,
      teammate: @teammate,
      current_person: current_person,
      current_type: @single_item_type,
      current_id: @single_item_id
    )
  end

  def single_item_object_queue_viewer_chip_label(viewer_state)
    VIEWER_STATE_CHIP_LABELS.fetch(viewer_state.to_sym, viewer_state.to_s.humanize)
  end

  def single_item_object_queue_viewer_chip_class(viewer_state)
    case viewer_state.to_sym
    when :your_turn
      "badge rounded-pill text-bg-danger"
    when :review_together
      "badge rounded-pill border border-warning text-warning bg-transparent"
    else
      "badge rounded-pill border text-muted bg-transparent"
    end
  end

  def single_item_object_queue_row_subcopy(row, employee_name:, manager_name:, manager_perspective:)
    other_name = manager_perspective ? employee_name : manager_name
    case row[:viewer_state]
    when :your_turn
      row[:open_check_in_present] ? "I still owe this" : "Start check-in"
    when :waiting
      "Waiting on #{other_name}"
    when :review_together
      "Ready to finalize"
    else
      "Nothing owed right now"
    end
  end

  def single_item_object_queue_health_tooltip(row)
    finalized_at = row[:last_finalized_at]
    return "Never finalized" if finalized_at.blank?

    "Last finalized #{time_ago_in_words(finalized_at)} ago"
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
  RESEARCH_AI_PROMPT_LOOKBACK_DAYS = 90

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

  # Slack @handle for AI research prompts; omit when we only have a real/display name.
  def single_item_check_in_slack_handle(teammate)
    identity = teammate&.slack_identity
    return nil if identity.blank?

    raw = identity.raw_data.is_a?(Hash) ? identity.raw_data : {}
    candidate = raw['name'].presence ||
                raw.dig('extra', 'raw_info', 'name').presence ||
                raw.dig('profile', 'display_name_normalized').presence ||
                raw.dig('profile', 'display_name').presence

    handle = candidate.to_s.strip
    return nil if handle.blank? || handle.include?(' ')

    handle.start_with?('@') ? handle : "@#{handle}"
  end

  def single_item_check_in_research_prompt_since_date(latest_finalized)
    completed_at = latest_finalized&.official_check_in_completed_at
    completed_at.present? ? completed_at : RESEARCH_AI_PROMPT_LOOKBACK_DAYS.days.ago
  end

  # Copy-paste prompt for Slack / Asana / Zoom / Meet AI tools to surface observation candidates.
  def single_item_check_in_research_ai_prompt(teammate:, latest_finalized:, focus_body:)
    full_name = teammate.person.preferred_first_then_last_display_name
    slack_handle = single_item_check_in_slack_handle(teammate)
    person_ref = slack_handle.present? ? "#{full_name} (#{slack_handle})" : full_name
    since_label = format_date_in_user_timezone(
      single_item_check_in_research_prompt_since_date(latest_finalized),
      format: '%B %-d, %Y'
    )

    <<~PROMPT.strip
      I'm preparing an observation-based check-in about #{person_ref}.

      We believe people grow best with specific, observation-based feedback. Please find examples of this person demonstrating the following between #{since_label} and today. Look for exceptional, good, misaligned, concerning, and poor examples of the behaviors these call for.

      List observations I should take into account in my check-in, and note whether each is a strong or weak example of pursuing these:

      #{focus_body.to_s.strip}
    PROMPT
  end

  def single_item_check_in_assignment_research_ai_prompt(teammate:, latest_finalized:, outcomes:)
    lines = Array(outcomes).filter_map do |outcome|
      plain = markdown_to_plain_text(outcome.description)
      next if plain.blank?

      "- #{plain}"
    end

    focus_body = if lines.any?
                   lines.join("\n")
                 else
                   '(No expected outcomes are defined for this assignment yet.)'
                 end

    single_item_check_in_research_ai_prompt(
      teammate: teammate,
      latest_finalized: latest_finalized,
      focus_body: focus_body
    )
  end

  def single_item_check_in_aspiration_research_ai_prompt(teammate:, aspiration:, latest_finalized:)
    description = markdown_to_plain_text(aspiration.description)
    focus_body = if description.present?
                   "#{aspiration.name}\n\n#{description}"
                 else
                   aspiration.name.to_s
                 end

    single_item_check_in_research_ai_prompt(
      teammate: teammate,
      latest_finalized: latest_finalized,
      focus_body: focus_body
    )
  end

  def single_item_check_in_ability_research_ai_prompt(teammate:, ability:)
    description = markdown_to_plain_text(ability.description)
    focus_body = if description.present?
                   "#{ability.name}\n\n#{description}"
                 else
                   ability.name.to_s
                 end

    single_item_check_in_research_ai_prompt(
      teammate: teammate,
      latest_finalized: nil,
      focus_body: focus_body
    )
  end
end
