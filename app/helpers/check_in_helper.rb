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

  # Popover content for latest finalized check-ins
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
end




