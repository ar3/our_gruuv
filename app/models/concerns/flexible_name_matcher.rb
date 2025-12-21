module FlexibleNameMatcher
  extend ActiveSupport::Concern

  # Generate all name variations for flexible matching
  def name_variations(name)
    return [] if name.blank?
    
    normalized = name.strip
    variations = [normalized]
    
    # Add &/and variations
    if normalized.include?('&')
      variations << normalized.gsub('&', 'and')
    end
    if normalized.match?(/\band\b/i)
      variations << normalized.gsub(/\band\b/i, '&')
    end
    
    # Add Senior variations (Sr, Sr., Senior)
    # Create variations by replacing each occurrence with each variant
    # Handle periods carefully - word boundaries don't work well with periods
    base = normalized.dup
    
    # Check if string contains any Senior variation
    if base.match?(/\b(Sr\.?|Senior)\b/i)
      # Variation 1: Replace all with "Sr" (no period)
      var1 = base.dup
      var1.gsub!(/\bSr\./i, 'Sr ')  # Replace "Sr." with "Sr " (space after)
      var1.gsub!(/\bSr\b(?!\.)/i, 'Sr')    # Replace "Sr" (not followed by .) with "Sr"
      var1.gsub!(/\bSenior\b/i, 'Sr') # Replace "Senior" with "Sr"
      var1.gsub!(/\s+/, ' ') # Normalize spaces
      var1.strip!
      variations << var1
      
      # Variation 2: Replace all with "Sr." (with period)
      var2 = base.dup
      var2.gsub!(/\bSr\./i, 'Sr.') # Keep "Sr." as is
      var2.gsub!(/\bSr\b(?!\.)/i, 'Sr.') # Replace "Sr" (not followed by .) with "Sr."
      var2.gsub!(/\bSenior\b/i, 'Sr.') # Replace "Senior" with "Sr."
      variations << var2
      
      # Variation 3: Replace all with "Senior"
      var3 = base.dup
      var3.gsub!(/\bSr\./i, 'Senior ')  # Replace "Sr." with "Senior " (space after)
      var3.gsub!(/\bSr\b(?!\.)/i, 'Senior') # Replace "Sr" (not followed by .) with "Senior"
      var3.gsub!(/\bSenior\b/i, 'Senior') # Keep "Senior" as is
      var3.gsub!(/\s+/, ' ') # Normalize spaces
      var3.strip!
      variations << var3
    end
    
    variations.uniq
  end

  # Find a record using flexible name matching
  def find_with_flexible_matching(model_class, name_field, search_name, scope = nil)
    if search_name.blank?
      Rails.logger.debug "❌❌❌ FlexibleNameMatcher: Search name is blank for #{model_class.name}.#{name_field}"
      return nil
    end
    
    variations = name_variations(search_name)
    Rails.logger.debug "❌❌❌ FlexibleNameMatcher: Searching #{model_class.name}.#{name_field} for '#{search_name}' with #{variations.length} variations: #{variations.inspect}"
    
    base_query = model_class.where(name_field => variations)
    base_query = base_query.merge(scope) if scope
    
    variations.each do |variation|
      result = base_query.find_by(name_field => variation)
      if result
        Rails.logger.debug "❌❌❌ FlexibleNameMatcher: Found match for '#{search_name}' using variation '#{variation}': #{model_class.name} id=#{result.id}"
        return result
      end
    end
    
    Rails.logger.debug "❌❌❌ FlexibleNameMatcher: No match found for '#{search_name}' in #{model_class.name}.#{name_field}"
    nil
  end
end

