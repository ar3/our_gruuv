class ObservationRatingDecorator < Draper::Decorator
  delegate_all

  def rating_to_words
    case rating
    when 'strongly_agree'
      'Exceptional'
    when 'agree'
      'Good'
    when 'na'
      'N/A'
    when 'disagree'
      'Opportunity'
    when 'strongly_disagree'
      'Major Concern'
    end
  end

  def rating_icon
    case rating
    when 'strongly_agree'
      '⭐'
    when 'agree'
      '👍'
    when 'na'
      '👁️‍🗨️'
    when 'disagree'
      '👎'
    when 'strongly_disagree'
      '⭕'
    end
  end

  def rating_color_class
    case rating
    when 'strongly_agree'
      'text-success'
    when 'agree'
      'text-primary'
    when 'na'
      'text-muted'
    when 'disagree'
      'text-warning'
    when 'strongly_disagree'
      'text-danger'
    end
  end

  def descriptive_text
    "#{rating_to_words} display of #{rateable.name}"
  end

  def to_descriptive_html
    "<strong>#{rating_to_words}</strong> display of <strong>#{rateable.name}</strong>"
  end
end
