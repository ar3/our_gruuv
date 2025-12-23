class ObservationRatingDecorator < Draper::Decorator
  delegate_all

  def rating_to_words
    case rating
    when 'strongly_agree'
      'Exceptional'
    when 'agree'
      'Solid'
    when 'na'
      'N/A'
    when 'disagree'
      'Mis-aligned'
    when 'strongly_disagree'
      'Concerning'
    end
  end

  def rating_icon
    case rating
    when 'strongly_agree'
      'bi-star-fill'
    when 'agree'
      'bi-hand-thumbs-up'
    when 'na'
      'bi-dash-circle'
    when 'disagree'
      'bi-hand-thumbs-down'
    when 'strongly_disagree'
      'bi-x-circle'
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
