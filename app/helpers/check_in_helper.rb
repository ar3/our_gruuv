module CheckInHelper
  FRESH_PILL_DAYS = CheckInBehavior::CLARITY_CRYSTAL_CLEAR_DAYS
  WARNING_PILL_DAYS = CheckInBehavior::CLARITY_BLURRED_DAYS
  NO_ACTION_NEEDED_DAYS = CheckInBehavior::CLARITY_CLEAR_DAYS

  # Reference the single source of truth from EmploymentTenure
  def position_rating_display(rating)
    return 'Not Rated' if rating.nil?
    data = EmploymentTenure::POSITION_RATINGS[rating]
    return 'Not Rated' if data.nil?
    "#{data[:emoji]} #{data[:label]}"
  end
  
  def position_rating_options
    EmploymentTenure::POSITION_RATINGS.map do |value, data|
      ["#{data[:emoji]} #{data[:label]} - #{data[:description]}", value]
    end
  end
  
  ASSIGNMENT_RATINGS = {
    'working_to_meet' => { emoji: '🟡', label: 'Working to Meet' },
    'meeting' => { emoji: '🔵', label: 'Meeting' },
    'exceeding' => { emoji: '🟢', label: 'Exceeding' }
  }.freeze
  
  ASPIRATION_RATINGS = {
    'working_to_meet' => { emoji: '🟡', label: 'Working to Meet' },
    'meeting' => { emoji: '🔵', label: 'Meeting' },
    'exceeding' => { emoji: '🟢', label: 'Exceeding' }
  }.freeze
  
  def aspiration_rating_display(rating)
    return 'Not Rated' if rating.nil?
    data = ASPIRATION_RATINGS[rating]
    "#{data[:emoji]} #{data[:label]}"
  end
  
  def aspiration_rating_options
    ASPIRATION_RATINGS.map do |value, data|
      ["#{data[:emoji]} #{data[:label]}", value]
    end
  end
  
  def assignment_rating_display(rating)
    return 'Not Rated' if rating.nil?
    data = ASSIGNMENT_RATINGS[rating]
    "#{data[:emoji]} #{data[:label]}"
  end
  
  def assignment_rating_options
    ASSIGNMENT_RATINGS.map do |value, data|
      ["#{data[:emoji]} #{data[:label]}", value]
    end
  end

  # Options for the official rating dropdown on the finalization page only. Includes a nil option.
  def assignment_official_rating_options_for_finalization
    [["Never took this on", ""]] + assignment_rating_options
  end

  # Phrase for "they <alignment> taking on this assignment" in audit check-in sentences
  def assignment_alignment_phrase(alignment)
    return 'did not specify alignment' if alignment.blank?
    case alignment.to_s
    when 'love' then 'loved'
    when 'like' then 'liked'
    when 'neutral' then 'were neutral about'
    when 'prefer_not' then 'preferred not'
    when 'only_if_necessary' then 'would only if necessary'
    else alignment.to_s.humanize.downcase
    end
  end

  # Past-tense phrase for "they'd X again" in assignment energy/alignment sentence
  def assignment_alignment_phrase_past(alignment)
    return nil if alignment.blank?
    case alignment.to_s
    when 'love' then "they'd love to do it again"
    when 'like' then "they'd like to do it again"
    when 'neutral' then "they're indifferent about taking it on again"
    when 'prefer_not' then "they'd prefer not to take it on again"
    when 'only_if_necessary' then "they'd only take it on again if necessary"
    else "they'd #{alignment.to_s.humanize.downcase} to do it again"
    end
  end

  # Sentence combining energy and alignment for assignment check-in: "When **name** thinks about..."
  def assignment_energy_alignment_sentence(check_in)
    return '' unless check_in
    casual_name = check_in.teammate.person.casual_name
    assignment_title = check_in.assignment.title
    energy = check_in.actual_energy_percentage
    alignment_phrase = assignment_alignment_phrase_past(check_in.employee_personal_alignment)
    return '' if energy.nil? && alignment_phrase.blank?
    energy_part = energy.present? ? "they spent about <strong>#{h(energy)}</strong>% of their energy on this assignment" : nil
    alignment_part = alignment_phrase.present? ? "<strong>#{h(alignment_phrase)}</strong>" : nil
    parts = [energy_part, alignment_part].compact
    return '' if parts.empty?
    sentence = "When <strong>#{h(casual_name)}</strong> thinks about them recently taking on <strong>#{h(assignment_title)}</strong>, "
    sentence << parts.join(' and ') + '.'
    sentence.html_safe
  end
  
  def energy_percentage_options
    (0..20).map { |i| ["#{i * 5}%", i * 5] }
  end
  
  def check_in_status_badge(check_in)
    return content_tag(:span, '📝 In Progress', class: 'badge badge-secondary') unless check_in
    
    if check_in.officially_completed?
      content_tag(:span, '✅ Complete', class: 'badge badge-success')
    elsif check_in.ready_for_finalization?
      content_tag(:span, '⏳ Ready to Finalize', class: 'badge badge-warning')
    elsif check_in.employee_completed? && !check_in.manager_completed?
      content_tag(:span, '⏳ Waiting for Manager', class: 'badge badge-info')
    elsif check_in.manager_completed? && !check_in.employee_completed?
      content_tag(:span, '⏳ Waiting for Employee', class: 'badge badge-info')
    else
      content_tag(:span, '📝 In Progress', class: 'badge badge-secondary')
    end
  end
  
  def partial_exists?(partial_name)
    lookup_context.exists?(partial_name, [], true)
  end

  # Label for "Last Finalized" pill: "Last Finalized X ago" or "Never Finalized"
  def last_finalized_label(latest_check_in)
    return 'Never Finalized' if latest_check_in.blank?
    "Last Finalized #{time_ago_in_words(latest_check_in.official_check_in_completed_at)} ago"
  end

  # Bootstrap badge class for pill by recency:
  # green <= crystal clear days, info <= clear days, warning <= blurred days, danger after that, grey never.
  def last_finalized_pill_class(latest_check_in)
    return 'bg-secondary' if latest_check_in.blank?
    days = (Time.zone.today - latest_check_in.official_check_in_completed_at.to_date).to_i
    if days <= FRESH_PILL_DAYS
      'bg-success'
    elsif days <= NO_ACTION_NEEDED_DAYS
      'bg-info text-dark'
    elsif days <= WARNING_PILL_DAYS
      'bg-warning text-dark'
    else
      'bg-danger'
    end
  end

  # True when the "Last Finalized" pill is green (recently finalized, no action needed).
  def last_finalized_recent?(latest_check_in)
    last_finalized_pill_class(latest_check_in) == 'bg-success'
  end

  # Up Next queue: Bootstrap classes for the per-perspective status pill (green / yellow / red buckets).
  def up_next_status_pill_class(bucket)
    case bucket&.to_sym
    when :green then "bg-success"
    when :yellow then "bg-warning text-dark"
    else "bg-danger"
    end
  end

  # Up Next queue: copy for the per-perspective status pill.
  def up_next_status_pill_message(bucket, person_name:)
    name = person_name.presence || "They"
    case bucket&.to_sym
    when :green
      "#{name} doesn't need to do anything with this right now"
    when :yellow
      "if #{name} wants to do an early check-in they could, but doesn't need to do anything with this right now"
    else
      "#{name} should do a check-in right now"
    end
  end

  # True Day-to-Day spotlight: time until clarity deadline from last finalized (matches _last_finalized_pill branches).
  # Returns "now" when there is no anchor finalized time or the deadline has passed.
  def complete_picture_next_check_in_word(official_check_in_completed_at)
    return 'now' if official_check_in_completed_at.blank?

    completed_at = official_check_in_completed_at
    pseudo = Struct.new(:official_check_in_completed_at).new(completed_at)
    pill_class = last_finalized_pill_class(pseudo)

    deadline = if pill_class == 'bg-info text-dark'
                 completed_at + CheckInBehavior::CLARITY_BLURRED_DAYS.days
               else
                 completed_at + CheckInBehavior::CLARITY_CLEAR_DAYS.days
               end

    return 'now' if Time.current >= deadline

    distance_of_time_in_words(Time.current, deadline)
  end

  # True when open row fields should be hidden by default because the item is fresh
  # and no one has started the current check-in yet.
  def hide_fresh_open_check_in_fields?(check_in, latest_finalized, view_mode:)
    return false if check_in.blank?
    return false unless check_in.open?
    return false unless latest_finalized&.clarity_level == :crystal_clear
    return false if view_mode == :readonly
    return false unless other_side_incomplete_for_view?(check_in, view_mode)
    return false unless viewer_side_fields_unset_for_fresh_hide?(check_in, view_mode)

    true
  end

  # 1-by-1 check-in pages: same employee vs manager rule as bulk (CheckInsController#determine_view_mode).
  def single_item_check_in_view_mode(teammate, current_person)
    return :manager if teammate.blank? || current_person.blank?

    current_person == teammate.person ? :employee : :manager
  end

  def single_item_check_in_status_for_view(check_in, teammate, current_person)
    mode = single_item_check_in_view_mode(teammate, current_person)
    complete = mode == :employee ? check_in.employee_completed? : check_in.manager_completed?
    complete ? "complete" : "draft"
  end

  def single_item_check_in_counterparty_name(teammate, current_person)
    mode = single_item_check_in_view_mode(teammate, current_person)
    if mode == :employee
      teammate.current_manager&.casual_name.presence || "Manager"
    else
      teammate.person.casual_name.presence || "Employee"
    end
  end

  def single_item_check_in_completed_at_for_view(check_in, teammate, current_person)
    mode = single_item_check_in_view_mode(teammate, current_person)
    mode == :employee ? check_in.employee_completed_at : check_in.manager_completed_at
  end

  # 1-by-1 check-in form: second line when the counterparty has not completed yet.
  def single_item_check_in_counterparty_not_completed_clause(check_in, teammate, current_person)
    return "" if check_in.blank? || teammate.blank? || current_person.blank?

    counterparty = single_item_check_in_counterparty_name(teammate, current_person)
    "#{counterparty} has not completed their check-in yet."
  end

  def single_item_check_in_counterparty_completed?(check_in, teammate, current_person)
    check_in_counterparty_completion_detail_context(check_in, teammate: teammate, current_person: current_person).present?
  end

  def single_item_check_in_move_destination_text(next_requires_check_in:, next_item:, show_check_in_status_done: false)
    if next_requires_check_in && !show_check_in_status_done && next_item.present?
      next_item[:name].to_s
    else
      "Check-in Status, because you are done!"
    end
  end

  def single_item_check_in_primary_button_text(is_complete:, next_requires_check_in:, next_item:, show_check_in_status_done: false)
    destination = single_item_check_in_move_destination_text(
      next_requires_check_in: next_requires_check_in,
      next_item: next_item,
      show_check_in_status_done: show_check_in_status_done
    )
    if is_complete
      "Update and move to #{destination}"
    else
      "Mark as Ready for review and move to #{destination}"
    end
  end

  def single_item_check_in_primary_caption(is_complete:, counterparty_name:, completed_at:, check_in:, teammate:, current_person:, organization: nil)
    mode = single_item_check_in_view_mode(teammate, current_person)
    other_done, other_completed_at =
      if mode == :employee
        [check_in.manager_completed?, check_in.manager_completed_at]
      else
        [check_in.employee_completed?, check_in.employee_completed_at]
      end

    if is_complete
      your_completion_recency =
        if completed_at.present?
          "#{time_ago_in_words(completed_at)} ago"
        else
          "recently"
        end

      if other_done
        other_completion_recency =
          if other_completed_at.present?
            "#{time_ago_in_words(other_completed_at)} ago"
          else
            "recently"
          end

        visible_since_time = [completed_at, other_completed_at].compact.min
        visible_since_recency =
          if visible_since_time.present?
            "#{time_ago_in_words(visible_since_time)} ago"
          else
            "recently"
          end

        caption_prefix =
          "You completed your individual check-in #{your_completion_recency}. #{counterparty_name} completed their individual check-in #{other_completion_recency}, and has been able to see your response since #{visible_since_recency}, and you are ready to have your "
        if organization.present? && teammate.present?
          (h(caption_prefix) + link_to("review together", organization_company_teammate_finalization_path(organization, teammate), class: "link-secondary") + ".").html_safe
        else
          "#{caption_prefix}review together."
        end
      else
        "You completed your individual check-in #{your_completion_recency}. #{counterparty_name} has not completed their side of the check-in and therefore cannot see your response yet."
      end
    else
      if other_done
        "#{counterparty_name} has completed their individual check-in and you will be able to see their response and they will be able to see your response when you click this button."
      else
        "#{counterparty_name} has not completed their individual check-in on this yet, and will not see your response immediately... they will only after they complete their side first."
      end
    end
  end

  def single_item_check_in_secondary_button_text(is_complete:)
    if is_complete
      "Mark as Draft and stay here"
    else
      "Save as Draft and stay here"
    end
  end

  def single_item_check_in_secondary_caption(is_complete:, counterparty_name:)
    if is_complete
      "#{counterparty_name} will NO LONGER be able to see your response until you've marked this as ready for review"
    else
      "#{counterparty_name} will NOT be able to see your response until you've marked this as ready for review"
    end
  end

  def single_item_check_in_delete_allowed?(check_in, teammate, current_person)
    return false if check_in.blank? || teammate.blank? || current_person.blank?

    view_mode = single_item_check_in_view_mode(teammate, current_person)
    check_in.respond_to?(:deletable_by_viewer_role?) && check_in.deletable_by_viewer_role?(view_mode)
  end

  def single_item_check_in_delete_tooltip(check_in, teammate, current_person, current_url)
    counterparty = single_item_check_in_counterparty_name(teammate, current_person)
    "#{counterparty} has to remove the values they've put in for this check-in first. Send them this URL and have them clear their answers, then you'll be able to delete this check-in: #{current_url}"
  end

  def single_item_check_in_mandatory_delete_blocked?(check_in, teammate, organization)
    return false if check_in.blank? || teammate.blank?

    case check_in
    when AssignmentCheckIn
      return false if organization.blank?

      check_in.assignment.required_on_position_for_teammate?(teammate, organization)
    when AspirationCheckIn
      check_in.aspiration.company_level_aspirational_value?
    else
      false
    end
  end

  def single_item_check_in_delete_mandatory_tooltip(check_in)
    case check_in
    when AssignmentCheckIn
      "Can't delete this check-in — it's a required assignment for this position."
    when AspirationCheckIn
      "Can't delete this check-in — it's a company aspirational value."
    else
      "Can't delete this check-in."
    end
  end

  def single_item_hide_fresh_open_check_in_form?(check_in, latest_finalized, teammate:, current_person:)
    hide_fresh_open_check_in_fields?(
      check_in,
      latest_finalized,
      view_mode: single_item_check_in_view_mode(teammate, current_person)
    )
  end

  def single_item_crystal_clear_recency_phrase(latest_finalized)
    return "" if latest_finalized.blank? || latest_finalized.official_check_in_completed_at.blank?

    "#{time_ago_in_words(latest_finalized.official_check_in_completed_at)} ago"
  end

  def last_finalized_days_ago(latest_check_in)
    return nil if latest_check_in.blank?

    (Time.zone.today - latest_check_in.official_check_in_completed_at.to_date).to_i
  end

  def other_side_incomplete_for_view?(check_in, view_mode)
    case view_mode
    when :employee
      !check_in.manager_completed?
    when :manager
      !check_in.employee_completed?
    else
      false
    end
  end

  def viewer_side_fields_unset_for_fresh_hide?(check_in, view_mode)
    case check_in
    when AssignmentCheckIn
      assignment_viewer_side_fields_unset?(check_in, view_mode)
    when AspirationCheckIn
      aspiration_viewer_side_fields_unset?(check_in, view_mode)
    when PositionCheckIn
      position_viewer_side_fields_unset?(check_in, view_mode)
    else
      false
    end
  end

  def assignment_viewer_side_fields_unset?(check_in, view_mode)
    case view_mode
    when :employee
      default_energy = check_in.assignment_tenure&.anticipated_energy_percentage
      energy_unset = check_in.actual_energy_percentage.nil? || check_in.actual_energy_percentage == default_energy
      check_in.employee_rating.blank? &&
        check_in.employee_private_notes.to_s.strip.blank? &&
        check_in.employee_personal_alignment.blank? &&
        energy_unset
    when :manager
      check_in.manager_rating.blank? &&
        check_in.manager_private_notes.to_s.strip.blank?
    else
      false
    end
  end

  def aspiration_viewer_side_fields_unset?(check_in, view_mode)
    case view_mode
    when :employee
      check_in.employee_rating.blank? &&
        check_in.employee_private_notes.to_s.strip.blank?
    when :manager
      check_in.manager_rating.blank? &&
        check_in.manager_private_notes.to_s.strip.blank?
    else
      false
    end
  end

  def position_viewer_side_fields_unset?(check_in, view_mode)
    case view_mode
    when :employee
      check_in.employee_rating.blank? &&
        check_in.employee_private_notes.to_s.strip.blank?
    when :manager
      check_in.manager_rating.blank? &&
        check_in.manager_private_notes.to_s.strip.blank?
    else
      false
    end
  end

  # Popover content: same sentence structure as audit page (shared partial)
  def last_finalized_check_in_popover_content(check_in, employee_name, sentence_type)
    return '' if check_in.blank?
    render(partial: 'shared/check_in_finalized_sentences', locals: { check_in: check_in, employee_name: employee_name, sentence_type: sentence_type })
  end

  # Popover content for latest finalized check-ins (legacy: used only when we need HTML for popover from latest)
  def latest_position_check_in_popover_content(teammate)
    latest = PositionCheckIn.latest_finalized_for(teammate)
    return "No completed check-ins yet" unless latest
    
    content = []
    content << "<strong>Finalized:</strong> #{latest.official_check_in_completed_at.strftime('%m/%d/%Y')}"
    content << "<strong>Rating:</strong> #{position_rating_display(latest.official_rating)}"
    content << "<strong>By:</strong> #{latest.finalized_by_teammate&.person&.display_name}" if latest.finalized_by_teammate
    content << "<br><em>#{latest.shared_notes}</em>" if latest.shared_notes.present?
    content.join('<br>')
  end

  def latest_assignment_check_in_popover_content(teammate, assignment)
    latest = AssignmentCheckIn.latest_finalized_for(teammate, assignment)
    return "No completed check-ins yet" unless latest
    
    content = []
    content << "<strong>Finalized:</strong> #{latest.official_check_in_completed_at.strftime('%m/%d/%Y')}"
    content << "<strong>Rating:</strong> #{assignment_rating_display(latest.official_rating)}"
    content << "<strong>By:</strong> #{latest.finalized_by_teammate&.person&.display_name}" if latest.finalized_by_teammate
    content << "<br><em>#{latest.shared_notes}</em>" if latest.shared_notes.present?
    content.join('<br>')
  end

  def latest_aspiration_check_in_popover_content(teammate, aspiration)
    latest = AspirationCheckIn.latest_finalized_for(teammate, aspiration)
    return "No completed check-ins yet" unless latest
    
    content = []
    content << "<strong>Finalized:</strong> #{latest.official_check_in_completed_at.strftime('%m/%d/%Y')}"
    content << "<strong>Rating:</strong> #{aspiration_rating_display(latest.official_rating)}"
    content << "<strong>By:</strong> #{latest.finalized_by_teammate&.person&.display_name}" if latest.finalized_by_teammate
    content << "<br><em>#{latest.shared_notes}</em>" if latest.shared_notes.present?
    content.join('<br>')
  end

  # Generic status label for single-item check-in rows (position/assignment/aspiration).
  # latest_finalized_at: time of most recent finalized check-in for this item (nil if never).
  def single_item_check_in_status_label(check_in, latest_finalized_at, teammate)
    if check_in.officially_completed?
      return 'Acknowledged' if check_in.maap_snapshot&.acknowledged?
      return 'Waiting to be acknowledged'
    end
    if check_in.ready_for_finalization?
      return 'Waiting to be reviewed'
    end
    last_finalized_days_ago = latest_finalized_at ? ((Time.current - latest_finalized_at) / 1.day).to_i : 9999
    if last_finalized_days_ago < NO_ACTION_NEEDED_DAYS
      return 'Nothing to do yet'
    end
    employee_name = teammate.person.casual_name.presence || 'Employee'
    manager_name = teammate.current_manager&.casual_name.presence || 'Manager'
    if !check_in.employee_completed? && !check_in.manager_completed?
      'Waiting for both'
    elsif !check_in.employee_completed?
      "Waiting for #{employee_name}"
    elsif !check_in.manager_completed?
      "Waiting for #{manager_name}"
    else
      'Waiting to be reviewed'
    end
  end

  # Person we are "waiting for" when only one side has completed (for display under Complete pill).
  def single_item_check_in_waiting_for_name(check_in, teammate)
    return nil if check_in.employee_completed? && check_in.manager_completed?
    return teammate.person.casual_name.presence || 'Employee' if !check_in.employee_completed?
    teammate.current_manager&.casual_name.presence || 'Manager'
  end

  # True when the "Make Changes" toggle should use warning styling: no finalized check-in
  # within clear days and the current side has not marked the row complete.
  # and the current side (employee or manager) has not marked the row complete.
  # latest_finalized: the latest finalized check-in record for this item (or nil).
  # role: :employee or :manager (which side's "Make Changes" we're rendering).
  def single_item_check_in_make_changes_needs_attention?(check_in, latest_finalized, role)
    latest_at = latest_finalized&.official_check_in_completed_at
    last_finalized_days_ago = latest_at ? ((Time.current - latest_at) / 1.day).to_i : 9999
    return false if last_finalized_days_ago < NO_ACTION_NEEDED_DAYS
    role == :employee ? !check_in.employee_completed? : !check_in.manager_completed?
  end

  def aspiration_check_in_status_label(check_in, latest_finalized_at, teammate)
    single_item_check_in_status_label(check_in, latest_finalized_at, teammate)
  end

  def aspiration_check_in_waiting_for_name(check_in, teammate)
    single_item_check_in_waiting_for_name(check_in, teammate)
  end

  # Tooltip for name/title submits on the unified check-ins page that open the single-item flow.
  def unified_check_ins_single_item_submit_title
    'Click here to do the same check-in process as you are doing on this page, but focusing on just this one thing at a time!'
  end

  # Review-most-recent: outline CTA when the open check-in is ready for joint finalization (both sides complete).
  def review_most_recent_joint_review_button_label(check_in, employee_name, manager_name)
    return '' if check_in.blank?

    object_label = case check_in
    when AspirationCheckIn
      check_in.aspiration&.name.presence || 'this value'
    when AssignmentCheckIn
      check_in.assignment&.title.presence || 'this assignment'
    when PositionCheckIn
      check_in.employment_tenure&.position&.display_name.presence || 'this position'
    else
      'this check-in'
    end

    "Time for #{employee_name} and #{manager_name} to review #{object_label} together!"
  end

  # Review-most-recent (aspirations): finalized column — third sentence only ("they agreed ... Shared Notes").
  def aspiration_review_most_recent_last_reviewed_line(check_in, employee_name)
    return nil if check_in.blank?

    aspiration_check_in_sentence_lines(check_in, employee_name)[2]
  end

  # Review-most-recent (aspirations): employee or manager column — primary sentence + optional hr + draft / waiting.
  def aspiration_review_most_recent_side_segments(finalized:, open:, employee_name:, manager_name:, side:)
    primary_text = case side
    when :employee
      if finalized.present?
        aspiration_check_in_sentence_lines(finalized, employee_name)[0]
      end
    when :manager
      if finalized.present?
        aspiration_check_in_sentence_lines(finalized, employee_name)[1]
      end
    else
      nil
    end

    secondary_hr = false
    secondary_text = nil

    if open&.open?
      if side == :employee && open.employee_completed?
        secondary_hr = true
        if open.manager_completed?
          secondary_text = aspiration_check_in_sentence_lines(open, employee_name)[0]
        else
          secondary_text = "#{employee_name} completed a new check-in #{time_ago_in_words(open.employee_completed_at)} ago, and is waiting on #{manager_name} to complete their side."
        end
      elsif side == :manager && open.manager_completed?
        secondary_hr = true
        if open.employee_completed?
          secondary_text = aspiration_check_in_sentence_lines(open, employee_name)[1]
        else
          completed_by_manager_name = open.manager_completed_by_teammate&.person&.casual_name.presence || manager_name
          secondary_text = "#{completed_by_manager_name} completed a new check-in #{time_ago_in_words(open.manager_completed_at)} ago, and is waiting on #{employee_name} to complete their side."
        end
      end
    end

    { primary_text: primary_text, secondary_hr: secondary_hr, secondary_text: secondary_text }
  end

  # Review-most-recent (assignments): finalized column — third sentence only ("they agreed ... Shared Notes").
  def assignment_review_most_recent_last_reviewed_line(check_in, employee_name)
    return nil if check_in.blank?

    assignment_check_in_sentence_lines(check_in, employee_name)[2]
  end

  # Review-most-recent (assignments): employee or manager column — primary sentence + optional hr + draft / waiting.
  def assignment_review_most_recent_side_segments(finalized:, open:, employee_name:, manager_name:, side:)
    primary_text = case side
    when :employee
      if finalized.present?
        assignment_check_in_sentence_lines(finalized, employee_name)[0]
      end
    when :manager
      if finalized.present?
        assignment_check_in_sentence_lines(finalized, employee_name)[1]
      end
    else
      nil
    end

    secondary_hr = false
    secondary_text = nil

    if open&.open?
      if side == :employee && open.employee_completed?
        secondary_hr = true
        if open.manager_completed?
          secondary_text = assignment_check_in_sentence_lines(open, employee_name)[0]
        else
          secondary_text = "#{employee_name} completed a new check-in #{time_ago_in_words(open.employee_completed_at)} ago, and is waiting on #{manager_name} to complete their side."
        end
      elsif side == :manager && open.manager_completed?
        secondary_hr = true
        if open.employee_completed?
          secondary_text = assignment_check_in_sentence_lines(open, employee_name)[1]
        else
          completed_by_manager_name = open.manager_completed_by_teammate&.person&.casual_name.presence || manager_name
          secondary_text = "#{completed_by_manager_name} completed a new check-in #{time_ago_in_words(open.manager_completed_at)} ago, and is waiting on #{employee_name} to complete their side."
        end
      end
    end

    { primary_text: primary_text, secondary_hr: secondary_hr, secondary_text: secondary_text }
  end

  # Review-most-recent (position): finalized column — third sentence only ("they agreed ... Shared Notes").
  def position_review_most_recent_last_reviewed_line(check_in, employee_name)
    return nil if check_in.blank?

    position_check_in_sentence_lines(check_in, employee_name)[2]
  end

  # Review-most-recent (position): employee or manager column — primary sentence + optional hr + draft / waiting.
  def position_review_most_recent_side_segments(finalized:, open:, employee_name:, manager_name:, side:)
    primary_text = case side
    when :employee
      finalized.present? ? position_check_in_sentence_lines(finalized, employee_name)[0] : nil
    when :manager
      finalized.present? ? position_check_in_sentence_lines(finalized, employee_name)[1] : nil
    else
      nil
    end

    secondary_hr = false
    secondary_text = nil

    if open&.open?
      if side == :employee && open.employee_completed?
        secondary_hr = true
        if open.manager_completed?
          secondary_text = position_check_in_sentence_lines(open, employee_name)[0]
        else
          secondary_text = "#{employee_name} completed a new check-in #{time_ago_in_words(open.employee_completed_at)} ago, and is waiting on #{manager_name} to complete their side."
        end
      elsif side == :manager && open.manager_completed?
        secondary_hr = true
        if open.employee_completed?
          secondary_text = position_check_in_sentence_lines(open, employee_name)[1]
        else
          completed_by_manager_name = open.manager_completed_by_teammate&.person&.casual_name.presence || manager_name
          secondary_text = "#{completed_by_manager_name} completed a new check-in #{time_ago_in_words(open.manager_completed_at)} ago, and is waiting on #{employee_name} to complete their side."
        end
      end
    end

    { primary_text: primary_text, secondary_hr: secondary_hr, secondary_text: secondary_text }
  end

  # Get Shit Done — check-ins awaiting input: groups sorted by employee casual name (A–Z).
  def check_ins_awaiting_input_by_employee(check_ins)
    check_ins
      .group_by(&:company_teammate)
      .sort_by { |teammate, _| teammate.person.casual_name.to_s.downcase }
  end

  # Group header when the other participant has completed their side.
  def check_ins_awaiting_input_group_header(check_ins, employee_teammate, viewing_teammate)
    count = check_ins.size
    if employee_teammate == viewing_teammate
      manager_names = check_ins.filter_map do |ci|
        ci.manager_completed_by_teammate&.person&.casual_name.presence
      end.uniq
      if manager_names.many?
        "Your managers have completed their side of your #{pluralize(count, 'check-in')}"
      else
        "Your manager has completed their side of your #{pluralize(count, 'check-in')}"
      end
    else
      employee_name = employee_teammate.person.casual_name.presence || 'Employee'
      awaiting_verb = count == 1 ? 'is' : 'are'
      "#{employee_name} has completed their side of #{pluralize(count, 'check-in')} " \
        "and #{awaiting_verb} awaiting you to complete your side"
    end
  end

  # Counterparty completion blurb: completer, object, and observation timeframe (HTML; object names and dates bold).
  def check_in_counterparty_completion_detail_line(check_in, teammate: nil, current_person: nil)
    context = check_in_counterparty_completion_detail_context(check_in, teammate: teammate, current_person: current_person)
    return '' unless context

    build_check_in_counterparty_completion_detail_html(context)
  end

  # Get Shit Done: link to the 1-by-1 check-in page for this record (assignment / aspiration / position).
  def get_shit_done_check_in_review_path(organization, check_in)
    case check_in
    when AssignmentCheckIn
      organization_teammate_assignment_path(organization, check_in.company_teammate, check_in.assignment)
    when AspirationCheckIn
      organization_teammate_aspiration_path(organization, check_in.company_teammate, check_in.aspiration)
    when PositionCheckIn
      position_check_in_organization_teammate_path(organization, check_in.company_teammate)
    else
      organization_company_teammate_check_ins_path(organization, check_in.company_teammate)
    end
  end

  private

  def check_in_counterparty_completion_detail_context(check_in, teammate: nil, current_person: nil)
    return nil if check_in.blank?

    if teammate.present? && current_person.present?
      mode = single_item_check_in_view_mode(teammate, current_person)
      if mode == :employee
        return nil unless check_in.manager_completed?

        {
          completer_name: check_in.manager_completed_by_teammate&.person&.casual_name.presence || 'Manager',
          employee_name: check_in.company_teammate.person.casual_name.presence || 'Employee',
          completed_at: check_in.manager_completed_at,
          check_in: check_in
        }
      else
        return nil unless check_in.employee_completed?

        {
          completer_name: check_in.company_teammate.person.casual_name.presence || 'Employee',
          employee_name: check_in.company_teammate.person.casual_name.presence || 'Employee',
          completed_at: check_in.employee_completed_at,
          check_in: check_in
        }
      end
    elsif check_in.employee_completed? && !check_in.manager_completed?
      {
        completer_name: check_in.company_teammate.person.casual_name.presence || 'Employee',
        employee_name: check_in.company_teammate.person.casual_name.presence || 'Employee',
        completed_at: check_in.employee_completed_at,
        check_in: check_in
      }
    elsif check_in.manager_completed? && !check_in.employee_completed?
      {
        completer_name: check_in.manager_completed_by_teammate&.person&.casual_name.presence || 'Manager',
        employee_name: check_in.company_teammate.person.casual_name.presence || 'Employee',
        completed_at: check_in.manager_completed_at,
        check_in: check_in
      }
    end
  end

  def build_check_in_counterparty_completion_detail_html(context)
    check_in = context[:check_in]
    object_type, object_name = check_in_subject_object_labels(check_in)
    completed_on = check_in_completion_display_date(context[:completed_at])
    started_on = check_in_completion_display_date(check_in.check_in_started_on)
    bold_object = content_tag(:strong, object_name)
    bold_completed = content_tag(:strong, completed_on)
    bold_started = content_tag(:strong, started_on)

    safe_join([
      context[:completer_name],
      ' completed a check-in about the ',
      object_type,
      ', ',
      bold_object,
      ', on ',
      bold_completed,
      '. This was a reflection of their take on ',
      context[:employee_name],
      ' and ',
      bold_object,
      ' observing the timeframe between ',
      bold_started,
      ' to ',
      bold_completed,
      '.'
    ])
  end

  def check_in_subject_object_labels(check_in)
    case check_in
    when AssignmentCheckIn
      ['Assignment', check_in.assignment.title]
    when AspirationCheckIn
      ['Aspirational Value', check_in.aspiration.name]
    when PositionCheckIn
      ['Position', check_in.employment_tenure.position.display_name]
    else
      ['Check-in', 'this item']
    end
  end

  def check_in_completion_display_date(value)
    return '' unless value.present?

    value.to_date.strftime('%b %d, %Y')
  end
end




