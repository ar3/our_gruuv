module CheckInHelper
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

  # Bootstrap badge class for pill by recency: green <=45d, warning 46-90d, danger >90d, grey never
  def last_finalized_pill_class(latest_check_in)
    return 'bg-secondary' if latest_check_in.blank?
    days = (Time.current - latest_check_in.official_check_in_completed_at) / 1.day
    if days <= 45
      'bg-success'
    elsif days <= 90
      'bg-warning text-dark'
    else
      'bg-danger'
    end
  end

  # True when the "Last Finalized" pill is green (recently finalized, no action needed).
  def last_finalized_recent?(latest_check_in)
    last_finalized_pill_class(latest_check_in) == 'bg-success'
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
    if last_finalized_days_ago < 60
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

  # True when the "Make Changes" toggle should use warning styling: no finalized check-in in 60+ days
  # and the current side (employee or manager) has not marked the row complete.
  # latest_finalized: the latest finalized check-in record for this item (or nil).
  # role: :employee or :manager (which side's "Make Changes" we're rendering).
  def single_item_check_in_make_changes_needs_attention?(check_in, latest_finalized, role)
    latest_at = latest_finalized&.official_check_in_completed_at
    last_finalized_days_ago = latest_at ? ((Time.current - latest_at) / 1.day).to_i : 9999
    return false if last_finalized_days_ago < 60
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
          secondary_text = "#{manager_name} completed a new check-in #{time_ago_in_words(open.manager_completed_at)} ago, and is waiting on #{employee_name} to complete their side."
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
          secondary_text = "#{manager_name} completed a new check-in #{time_ago_in_words(open.manager_completed_at)} ago, and is waiting on #{employee_name} to complete their side."
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
          secondary_text = "#{manager_name} completed a new check-in #{time_ago_in_words(open.manager_completed_at)} ago, and is waiting on #{employee_name} to complete their side."
        end
      end
    end

    { primary_text: primary_text, secondary_hr: secondary_hr, secondary_text: secondary_text }
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
end




