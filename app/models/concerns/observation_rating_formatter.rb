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

  # Plain-text rating phrases for use in sentences (e.g. nudge copy).
  # Returns array of strings like "An Exceptional demonstration of Collaboration".
  # Skips N/A ratings.
  def rating_phrases_for_sentence
    rating_phrase_entries_for_sentence.map do |entry|
      "#{entry[:text_before_name]}#{entry[:name]}"
    end
  end

  # Structured rating phrase entries for building sentences with links.
  # Returns array of hashes: { text_before_name:, rateable:, name: }.
  # Returns a short label for one rating, e.g. "An Exceptional demonstration of Collaboration".
  def label_for_rating(observation_rating)
    rateable = observation_rating.rateable
    return nil unless rateable
    word = rating_to_word(observation_rating.rating)
    verb = verb_for_type(observation_rating.rateable_type)
    name = rateable_name(rateable)
    article = word.start_with?('A') ? 'An' : 'A'
    "#{article} #{word} #{verb} of #{name}"
  end

  # Skips N/A ratings. Use with internal_rateable_path(organization, rateable) in views.
  def rating_phrase_entries_for_sentence
    observation_ratings.reject { |r| r.rating.to_s == 'na' }.filter_map do |rating|
      rateable = rating.rateable
      next unless rateable
      word = rating_to_word(rating.rating)
      verb = verb_for_type(rating.rateable_type)
      name = rateable_name(rateable)
      article = word.start_with?('A') ? 'An' : 'A'
      { text_before_name: "#{article} #{word} #{verb} of ", rateable: rateable, name: name }
    end
  end

  private

  def rating_to_word(rating_value)
    case rating_value.to_s
    when 'strongly_agree'
      'Exceptional'
    when 'agree'
      'Solid'
    when 'disagree'
      'Mis-aligned'
    when 'strongly_disagree'
      'Concerning'
    else
      rating_value.to_s.humanize
    end
  end

  def public_url_for_rateable(rateable)
    case rateable.class.name
    when 'Ability'
      Rails.application.routes.url_helpers.organization_public_maap_ability_url(rateable.company, rateable)
    when 'Assignment'
      Rails.application.routes.url_helpers.organization_public_maap_assignment_url(rateable.company, rateable)
    when 'Aspiration'
      Rails.application.routes.url_helpers.organization_public_maap_aspiration_url(rateable.company, rateable)
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

