module EnmHelper
  # Agreement Likert scale for Phase 1 questions (6-point scale)
  def agreement_likert_options
    [
      ['Strongly Agree', 3],
      ['Agree', 2],
      ['Slightly Agree', 1],
      ['Slightly Disagree', -1],
      ['Disagree', -2],
      ['Strongly Disagree', -3]
    ]
  end

  # Comfort Likert scale for escalator questions (6-point scale)
  def comfort_likert_options
    [
      ['Very Comfortable', 3],
      ['Comfortable', 2],
      ['Slightly Comfortable', 1],
      ['Slightly Uncomfortable', -1],
      ['Uncomfortable', -2],
      ['Very Uncomfortable', -3]
    ]
  end

  # Prior disclosure options
  def prior_disclosure_options
    [
      ['No Notification or Agreement Expected', 'none'],
      ['Notification Expected', 'notification'],
      ['Agreement Expected', 'agreement']
    ]
  end

  # Post disclosure options
  def post_disclosure_options
    [
      ['Full, Expected', 'full'],
      ['Desired, but not Expected', 'desired'],
      ['Unwanted', 'unwanted']
    ]
  end

  # Helper to format disclosure option descriptions
  def prior_disclosure_description(option)
    case option
    when 'none'
      'I desire for you to navigate this autonomously.'
    when 'notification'
      'I need awareness beforehand so I can emotionally prepare.'
    when 'agreement'
      'I need to talk and agree before this happens to feel emotionally safe.'
    end
  end

  def post_disclosure_description(option)
    case option
    when 'full'
      'I expect full transparency afterward to maintain trust. Meaning, the exploring partner is expected to show things like text messages, shared locations, etc after every encounter'
    when 'desired'
      'I appreciate transparency but don\'t require it. Meaning, the exploring partner, if asked, is willing to say yes to show things like text messages, shared location, etc'
    when 'unwanted'
      'I\'d rather not know afterward; it would cause distress.'
    end
  end

  # Helper to get comfort level description
  def comfort_description(value)
    case value.to_i
    when 3
      'This would feel natural and safe within our relationship.'
    when 2
      'This would feel fine if disclosure expectations are met.'
    when 1
      'I\'d probably be okay with this, if handled carefully.'
    when -1
      'Could try to be okay / need significant emotional prep.'
    when -2
      'Disclosure helps, but I\'d still feel deeply uncomfortable.'
    when -3
      'Regardless of disclosure, this would feel unsafe.'
    end
  end
end
