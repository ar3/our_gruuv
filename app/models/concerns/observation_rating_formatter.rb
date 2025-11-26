module ObservationRatingFormatter
  extend ActiveSupport::Concern

  # Formats ratings grouped by type, then by rating level
  # Returns an array of formatted strings
  def format_ratings_by_type_and_level(format: :slack)
    return [] if observation_ratings.empty?

    # Group by type first
    by_type = observation_ratings.group_by(&:rateable_type)
    
    formatted_sentences = []
    
    # Process each type
    by_type.each do |rateable_type, ratings|
      # Group by rating level within each type
      by_rating = ratings.group_by(&:rating)
      
      by_rating.each do |rating_value, type_ratings|
        next if rating_value.to_s == 'na' # Skip N/A ratings
        
        rating_word = rating_to_word(rating_value)
        verb = verb_for_type(rateable_type)
        
        # Build links for each rateable item
        links = type_ratings.map do |rating|
          rateable = rating.rateable
          url = public_url_for_rateable(rateable)
          name = rateable_name(rateable)
          
          if format == :slack
            "<#{url}|#{name}>"
          else # :html
            "<a href=\"#{url}\">#{ERB::Util.html_escape(name)}</a>"
          end
        end
        
        # Create sentence: "An Exceptional demonstration of <links>"
        article = rating_word.start_with?('A') ? 'An' : 'A'
        
        if format == :html
          # For HTML, wrap rating word in <strong> tags and join links
          sentence = "#{article} <strong>#{rating_word}</strong> #{verb} of #{links.join(', ')}"
        else
          # For Slack, use * for bold
          sentence = "#{article} *#{rating_word}* #{verb} of #{links.join(', ')}"
        end
        
        formatted_sentences << sentence
      end
    end
    
    formatted_sentences
  end

  private

  def rating_to_word(rating_value)
    case rating_value.to_s
    when 'strongly_agree'
      'Exceptional'
    when 'agree'
      'Solid'
    when 'disagree'
      'Weak'
    when 'strongly_disagree'
      'Concerning'
    else
      rating_value.to_s.humanize
    end
  end

  def verb_for_type(rateable_type)
    case rateable_type
    when 'Ability'
      'demonstration'
    when 'Assignment'
      'execution'
    when 'Aspiration'
      'example'
    else
      'display'
    end
  end

  def public_url_for_rateable(rateable)
    case rateable.class.name
    when 'Ability'
      Rails.application.routes.url_helpers.organization_public_maap_ability_url(rateable.organization, rateable)
    when 'Assignment'
      Rails.application.routes.url_helpers.organization_public_maap_assignment_url(rateable.company, rateable)
    when 'Aspiration'
      Rails.application.routes.url_helpers.organization_public_maap_aspiration_url(rateable.organization, rateable)
    else
      '#'
    end
  end

  def rateable_name(rateable)
    case rateable.class.name
    when 'Ability'
      rateable.name
    when 'Assignment'
      rateable.title
    when 'Aspiration'
      rateable.name
    else
      rateable.to_s
    end
  end
end

