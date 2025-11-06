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
    macro_category = determine_macro_category(phase_1_data)
    readiness = determine_readiness(phase_1_data)
    
    { macro_category: macro_category, readiness: readiness }
  end
  
  def calculate_phase_2_results(phase_2_data)
    eci = calculate_eci(phase_2_data[:emotional_escalator])
    pci = calculate_pci(phase_2_data[:physical_escalator])
    style = determine_style_from_escalators(phase_2_data)
    
    { eci: eci, pci: pci, style: style }
  end
  
  def partial_phase_1_analysis(phase_1_data)
    return { stage: 'none' } if phase_1_data.blank?
    
    # Check most complete data first (Q5 > Q3 > Q1)
    # Check if Q1-Q5 are answered (full Phase 1)
    if phase_1_data[:active_emotional] && phase_1_data[:active_physical]
      readiness = determine_readiness(phase_1_data)
      sex_differences = detect_sex_differences(phase_1_data)
      
      return { 
        stage: 'after_q5', 
        readiness: readiness,
        sex_differences: sex_differences
      }
    end
    
    # Check if Q1-Q3 are answered
    if phase_1_data[:passive_emotional] && phase_1_data[:passive_physical]
      emotional_same = phase_1_data[:passive_emotional][:same_sex].to_i
      emotional_opposite = phase_1_data[:passive_emotional][:opposite_sex].to_i
      physical_same = phase_1_data[:passive_physical][:same_sex].to_i
      physical_opposite = phase_1_data[:passive_physical][:opposite_sex].to_i
      
      # Average same-sex and opposite-sex responses
      emotional_avg = (emotional_same + emotional_opposite) / 2.0
      physical_avg = (physical_same + physical_opposite) / 2.0
      
      if emotional_avg <= -1 && physical_avg <= -1
        return { stage: 'after_q3', likely_monogamous: true }
      elsif emotional_avg >= 1 && physical_avg <= -1
        return { stage: 'after_q3', likely_swinger: true }
      elsif emotional_avg >= 1 || physical_avg >= 1
        return { stage: 'after_q3', likely_poly: true }
      end
    end
    
    # Check if Q1 is answered
    if phase_1_data[:core_openness]
      core_same = phase_1_data[:core_openness][:same_sex].to_i
      core_opposite = phase_1_data[:core_openness][:opposite_sex].to_i
      
      # If either partner disagrees for both sexes, not ENM
      if core_same <= -1 && core_opposite <= -1
        return { stage: 'after_q1', likely_non_monogamous: false }
      elsif core_same >= 1 || core_opposite >= 1
        return { stage: 'after_q1', likely_non_monogamous: true }
      end
    end
    
    { stage: 'incomplete' }
  end
  
  def generate_final_code(macro_category, readiness, style)
    "#{macro_category}-#{readiness}-#{style}"
  end
  
  def get_typology_description(code)
    TYPOLOGY_CATALOG[code] || { nickname: 'Unknown Typology', description: 'This typology combination is not recognized.' }
  end
  
  private
  
  def determine_macro_category(phase_1_data)
    return 'M' unless phase_1_data[:passive_emotional] && phase_1_data[:passive_physical]
    
    # Average same-sex and opposite-sex responses
    emotional_same = phase_1_data[:passive_emotional][:same_sex].to_i
    emotional_opposite = phase_1_data[:passive_emotional][:opposite_sex].to_i
    physical_same = phase_1_data[:passive_physical][:same_sex].to_i
    physical_opposite = phase_1_data[:passive_physical][:opposite_sex].to_i
    
    emotional_avg = (emotional_same + emotional_opposite) / 2.0
    physical_avg = (physical_same + physical_opposite) / 2.0
    
    if emotional_avg <= -1 && physical_avg <= -1
      'M' # Monogamy-Leaning
    elsif emotional_avg >= 1 && physical_avg <= -1
      'H' # Heart-Leaning
    elsif emotional_avg <= -1 && physical_avg >= 1
      'S' # Swing-Leaning
    else
      'P' # Poly-Leaning
    end
  end
  
  def determine_readiness(phase_1_data)
    return 'C' unless phase_1_data[:active_emotional] && phase_1_data[:active_physical]
    
    # Average same-sex and opposite-sex responses
    emotional_same = phase_1_data[:active_emotional][:same_sex].to_i
    emotional_opposite = phase_1_data[:active_emotional][:opposite_sex].to_i
    physical_same = phase_1_data[:active_physical][:same_sex].to_i
    physical_opposite = phase_1_data[:active_physical][:opposite_sex].to_i
    
    emotional_avg = (emotional_same + emotional_opposite) / 2.0
    physical_avg = (physical_same + physical_opposite) / 2.0
    
    if emotional_avg <= 0 && physical_avg <= 0
      'C' # Closed
    elsif emotional_avg >= 2 && physical_avg <= 1
      'P' # Passive (Poly Ready)
    elsif emotional_avg <= 1 && physical_avg >= 2
      'P' # Passive (Swing Ready)
    elsif emotional_avg >= 2 && physical_avg >= 2
      'A' # Active
    else
      'P' # Default to Passive for mixed scenarios
    end
  end
  
  def detect_sex_differences(phase_1_data)
    differences = []
    
    phase_1_data.each do |question, data|
      next unless data.is_a?(Hash) && data[:same_sex] && data[:opposite_sex]
      
      same_score = data[:same_sex].to_i
      opposite_score = data[:opposite_sex].to_i
      
      if (same_score - opposite_score).abs >= 2
        differences << question
      end
    end
    
    differences.any?
  end
  
  def calculate_eci(emotional_escalator)
    return 0 if emotional_escalator.blank?
    
    comfort_scores = emotional_escalator.map do |step|
      # Average same-sex and opposite-sex comfort
      same_comfort = step[:comfort][:same_sex].to_i
      opposite_comfort = step[:comfort][:opposite_sex].to_i
      (same_comfort + opposite_comfort) / 2.0
    end
    
    comfort_scores.sum.to_f / comfort_scores.length
  end
  
  def calculate_pci(physical_escalator)
    return 0 if physical_escalator.blank?
    
    comfort_scores = physical_escalator.map do |step|
      # Average same-sex and opposite-sex comfort
      same_comfort = step[:comfort][:same_sex].to_i
      opposite_comfort = step[:comfort][:opposite_sex].to_i
      (same_comfort + opposite_comfort) / 2.0
    end
    
    comfort_scores.sum.to_f / comfort_scores.length
  end
  
  def determine_style_from_escalators(phase_2_data)
    # For now, use a simple heuristic based on escalator patterns
    # This will be enhanced when we have more data
    
    emotional_escalator = phase_2_data[:emotional_escalator] || []
    physical_escalator = phase_2_data[:physical_escalator] || []
    
    # Calculate average comfort levels
    emotional_avg = calculate_eci(emotional_escalator)
    physical_avg = calculate_pci(physical_escalator)
    
    # Simple style determination based on comfort patterns
    if emotional_avg >= 2 && physical_avg >= 2
      'K' # Kitchen Table - comfortable with both
    elsif emotional_avg >= 2 && physical_avg <= 0
      'H' # Hierarchical - emotional focus
    elsif emotional_avg <= 0 && physical_avg >= 2
      'S' # Swinger style - physical focus
    elsif emotional_avg <= -1 && physical_avg <= -1
      'F' # Polyfidelitous - very restrictive
    elsif emotional_avg <= -2 || physical_avg <= -2
      'R' # Relationship Anarchy - very open
    else
      'C' # Couple-Centric - moderate comfort
    end
  end
end
