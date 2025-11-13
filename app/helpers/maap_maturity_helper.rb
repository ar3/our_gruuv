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
    phase_status = position_type.maap_maturity_phase_status
    current_phase = position_type.maap_maturity_phase

    content_tag :div, class: 'maap-maturity-status-bar d-flex gap-1 mb-2' do
      (1..9).map do |phase|
        filled = phase_status[phase - 1]
        is_current = phase == current_phase
        
        classes = ['maap-maturity-phase']
        classes << 'filled' if filled
        classes << 'current' if is_current
        classes << 'unfilled' unless filled

        content_tag :div,
          phase,
          class: classes.join(' '),
          title: "#{PHASE_NAMES[phase]}: #{PHASE_DESCRIPTIONS[phase]}",
          data: { bs_toggle: 'tooltip', bs_placement: 'top' }
      end.join.html_safe
    end
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

