class Enm::PartnershipAnalyzerService
  def analyze_compatibility(assessment_codes)
    assessments = EnmAssessment.where(code: assessment_codes)
    return { relationship_type: 'M', compatibility_score: 0, divergences: [] } if assessments.empty?
    
    relationship_type = determine_relationship_type(assessments)
    compatibility_score = calculate_compatibility_score(assessments)
    divergences = identify_divergences(assessments)
    conversation_starters = generate_conversation_starters(assessments)
    
    {
      relationship_type: relationship_type,
      compatibility_score: compatibility_score,
      divergences: divergences,
      conversation_starters: conversation_starters,
      assessments_count: assessments.count
    }
  end
  
  def determine_relationship_type(assessments)
    return 'M' if assessments.empty?
    return assessments.first.macro_category if assessments.count == 1
    
    macro_categories = assessments.map(&:macro_category)
    
    # If all assessments have the same macro category
    if macro_categories.uniq.count == 1
      case macro_categories.first
      when 'M'
        'M' # Monogamy / Security-Focused
      when 'S'
        'S' # Swing / Exploratory Fun
      when 'P'
        'P' # Polysecure / Emotionally Networked
      when 'H'
        'H' # Heart-Leaning
      end
    else
      'H' # Hybrid / Bridging Worlds
    end
  end
  
  def identify_divergences(assessments)
    return [] if assessments.count <= 1
    
    divergences = []
    
    # Check macro category divergence
    macro_categories = assessments.map(&:macro_category).uniq
    divergences << :macro_category if macro_categories.count > 1
    
    # Check readiness divergence
    readiness_levels = assessments.map(&:readiness).uniq
    divergences << :readiness if readiness_levels.count > 1
    
    # Check style divergence
    styles = assessments.map(&:style).uniq
    divergences << :style if styles.count > 1
    
    divergences
  end
  
  def generate_conversation_starters(assessments)
    starters = []
    divergences = identify_divergences(assessments)
    
    if divergences.include?(:macro_category)
      starters << "Where do our comfort scores diverge the most?"
    end
    
    if divergences.include?(:readiness)
      starters << "What agreements can keep us aligned?"
    end
    
    if divergences.include?(:style)
      starters << "Which style axis changed since last time?"
    end
    
    starters << "What does 'safety' mean to each of us right now?"
    
    starters
  end
  
  private
  
  def calculate_compatibility_score(assessments)
    return 100 if assessments.count <= 1
    
    # Simple compatibility scoring based on alignment
    total_score = 0
    comparisons = 0
    
    assessments.each_with_index do |assessment1, i|
      assessments[(i+1)..-1].each do |assessment2|
        score = 0
        
        # Macro category alignment
        score += 25 if assessment1.macro_category == assessment2.macro_category
        
        # Readiness alignment
        score += 25 if assessment1.readiness == assessment2.readiness
        
        # Style alignment
        score += 25 if assessment1.style == assessment2.style
        
        # General compatibility bonus
        score += 25 if compatible_categories?(assessment1.macro_category, assessment2.macro_category)
        
        total_score += score
        comparisons += 1
      end
    end
    
    comparisons > 0 ? (total_score / comparisons).round : 0
  end
  
  def compatible_categories?(cat1, cat2)
    # Define compatibility matrix
    compatible_pairs = [
      ['M', 'M'],
      ['S', 'S'],
      ['P', 'P'],
      ['H', 'H'],
      ['P', 'S'], # Poly and Swing can be compatible
      ['S', 'P'],
      ['H', 'P'], # Heart and Poly can be compatible
      ['P', 'H']
    ]
    
    compatible_pairs.include?([cat1, cat2].sort)
  end
end
