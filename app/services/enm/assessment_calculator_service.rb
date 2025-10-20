class Enm::AssessmentCalculatorService
  TYPOLOGY_CATALOG = {
    'M-C-F' => { nickname: 'Anchor Pair', description: 'Deep dyadic bond; exclusivity priority.' },
    'S-A-H' => { nickname: 'Play Leads', description: 'Sex-positive couple exploring together.' },
    'S-P-K' => { nickname: 'Friendly Flirts', description: 'Socially sexual; prefer shared context.' },
    'P-A-K' => { nickname: 'Polysecure Networkers', description: 'Emotionally interwoven lovers and friends.' },
    'P-P-P' => { nickname: 'Quiet Polys', description: 'Value autonomy; minimal metamour overlap.' },
    'P-C-H' => { nickname: 'Structured Polys', description: 'Primary couple with soft secondaries.' },
    'S-A-S' => { nickname: 'Lifestyle Adventurers', description: 'Shared hobby of sexual exploration.' },
    'H-P-R' => { nickname: 'Emotional Explorers', description: 'Deep platonic or romantic bonds; rarely sexual.' },
    'P-A-R' => { nickname: 'Freeform Lovers', description: 'Reject hierarchy; fluid connection.' },
    'P-A-H' => { nickname: 'Network Navigators', description: 'Multiple structured relationships.' },
    'P-A-F' => { nickname: 'Closed Triad', description: 'Multi-partner exclusivity; family feel.' },
    'S-A-C' => { nickname: 'Unicorn Hunters', description: 'Seek shared third-partner experiences.' }
  }.freeze
  
  def calculate_phase_1_results(phase_1_data)
    macro_category = determine_macro_category(phase_1_data[:passive_openness])
    readiness = determine_readiness(phase_1_data[:active_readiness])
    
    { macro_category: macro_category, readiness: readiness }
  end
  
  def calculate_phase_2_results(phase_2_data)
    eci = calculate_eci(phase_2_data[:emotional_escalator])
    pci = calculate_pci(phase_2_data[:physical_escalator])
    style = determine_style(phase_2_data[:style_axes])
    
    { eci: eci, pci: pci, style: style }
  end
  
  def generate_final_code(macro_category, readiness, style)
    "#{macro_category}-#{readiness}-#{style}"
  end
  
  def get_typology_description(code)
    TYPOLOGY_CATALOG[code] || { nickname: 'Unknown Typology', description: 'This typology combination is not recognized.' }
  end
  
  private
  
  def determine_macro_category(passive_openness)
    emotional = passive_openness[:emotional].to_i
    physical = passive_openness[:physical].to_i
    
    if emotional <= -1 && physical <= -1
      'M' # Monogamy-Leaning
    elsif emotional >= 1 && physical <= -1
      'H' # Heart-Leaning
    elsif emotional <= -1 && physical >= 1
      'S' # Swing-Leaning
    else
      'P' # Poly-Leaning
    end
  end
  
  def determine_readiness(active_readiness)
    emotional_active = active_readiness[:emotional].to_i
    physical_active = active_readiness[:physical].to_i
    
    if emotional_active <= 0 && physical_active <= 0
      'C' # Closed
    elsif emotional_active >= 2 && physical_active <= 1
      'P' # Passive (Poly Ready)
    elsif emotional_active <= 1 && physical_active >= 2
      'P' # Passive (Swing Ready)
    elsif emotional_active >= 2 && physical_active >= 2
      'A' # Active
    else
      'P' # Default to Passive for mixed scenarios
    end
  end
  
  def calculate_eci(emotional_escalator)
    return 0 if emotional_escalator.blank?
    
    comfort_scores = emotional_escalator.map { |step| step[:comfort] }
    comfort_scores.sum.to_f / comfort_scores.length
  end
  
  def calculate_pci(physical_escalator)
    return 0 if physical_escalator.blank?
    
    comfort_scores = physical_escalator.map { |step| step[:comfort] }
    comfort_scores.sum.to_f / comfort_scores.length
  end
  
  def determine_style(style_axes)
    # Handle missing or empty style_axes
    return 'K' if style_axes.nil? || style_axes.empty?
    
    connection = style_axes[:connection] || 0
    emotional_structure = style_axes[:emotional_structure] || 0
    sexual_structure = style_axes[:sexual_structure] || 0
    initiation_pattern = style_axes[:initiation_pattern] || 0
    
    # Simple logic for style determination
    if connection >= 2
      'K' # Kitchen Table
    elsif emotional_structure >= 2
      'H' # Hierarchical
    elsif emotional_structure <= -2
      'R' # Relationship Anarchy
    elsif sexual_structure <= -2
      'F' # Polyfidelitous
    elsif sexual_structure >= 2
      'S' # Swinger style
    else
      'C' # Couple-Centric
    end
  end
end
