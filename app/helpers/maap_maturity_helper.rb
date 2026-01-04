module MaapMaturityHelper
  PHASE_NAMES = {
    1 => 'Define Assignments',
    2 => 'Review Assignments',
    3 => 'Calibrate Assignments',
    4 => 'Define Abilities',
    5 => 'Define Milestones',
    6 => 'Acknowledge Abilities',
    7 => 'Eligibility Framework',
    8 => 'Continuous Improvement',
    9 => '360 Observations'
  }.freeze

  PHASE_DESCRIPTIONS = {
    1 => 'Getting job descriptions broken into more manageable outcomes (LEGO blocks)',
    2 => 'Getting these Assignments discussed and honed',
    3 => 'Assigning and doing check-ins on these Assignments',
    4 => 'Stating what the major Skills, Knowledge, and overall Competencies we are looking for',
    5 => 'Adding more detail to each Ability by defining up to five Milestones',
    6 => 'Acknowledging observed demonstration of these Abilities',
    7 => 'Associating Assignments and Abilities into a cohesive framework for Position adjustments',
    8 => 'Establishing a culture where Positions, Assignments, Abilities, and Milestones are in constant improvement',
    9 => 'Establishing a culture with 365::360 degree observations against all aspects'
  }.freeze

  def maap_maturity_status_bar(position_type)
    begin
      phase_health = position_type.maap_maturity_phase_health_status
      current_phase = position_type.maap_maturity_phase.to_i
      
      # Ensure phase_health is an array with 9 elements
      phase_health = Array.new(9, :red) unless phase_health.is_a?(Array) && phase_health.length == 9
    rescue => e
      Rails.logger.error "Error getting maturity health status: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      phase_health = Array.new(9, :red)
      current_phase = 1
    end

    content_tag :div, class: 'maap-maturity-status-bar d-flex gap-1 mb-2' do
      (1..9).map do |phase|
        health = phase_health[phase - 1] || :red
        is_current = phase == current_phase
        
        classes = ['maap-maturity-phase']
        classes << health.to_s # :red, :yellow, or :green
        classes << 'current' if is_current

        begin
          popover_content = maap_maturity_phase_popover_content(position_type, phase)
        rescue => e
          Rails.logger.error "Error getting popover content for phase #{phase}: #{e.message}"
          popover_content = "Error loading phase information"
        end

        content_tag :div,
          phase.to_s,
          class: classes.join(' '),
          data: { 
            'bs-toggle': 'popover', 
            'bs-placement': 'top',
            'bs-content': popover_content,
            'bs-html': true,
            'bs-trigger': 'hover focus'
          }
      end.join.html_safe
    end
  end

  def maap_maturity_phase_popover_content(position_type, phase)
    reason_data = position_type.maap_maturity_phase_health_reason(phase)
    status = reason_data[:status]
    reason = reason_data[:reason]
    to_green = reason_data[:to_green]

    status_color = case status
    when :green
      'text-success'
    when :yellow
      'text-warning'
    when :red
      'text-danger'
    else
      'text-muted'
    end

    content_tag(:div, class: 'maap-maturity-popover') do
      content_tag(:strong, "Is #{status.to_s.capitalize} because:", class: status_color) +
      content_tag(:p, reason, class: 'mb-2') +
      content_tag(:strong, 'To get to green:') +
      content_tag(:p, to_green, class: 'mb-0')
    end.to_s
  end

  def maap_maturity_next_steps_text(position_type)
    content_tag :p, class: 'text-muted small mb-0' do
      position_type.maap_maturity_next_steps
    end
  end

  def maap_maturity_phase_name(phase)
    PHASE_NAMES[phase] || "Phase #{phase}"
  end

  def maap_maturity_phase_description(phase)
    PHASE_DESCRIPTIONS[phase] || ''
  end
end

