module AssignmentSurveysHelper
  def assignment_survey_indefinite_article(name)
    name.to_s.match?(/\A[aeiou]/i) ? "an" : "a"
  end

  def assignment_survey_understandable_prompt(name)
    article = assignment_survey_indefinite_article(name)
    safe_join([ "I clearly understand what is expected of me when I'm relied on to be #{article} ", tag.strong(name) ])
  end

  def assignment_survey_possible_prompt(name)
    article = assignment_survey_indefinite_article(name)
    safe_join([ "I can realistically see myself meeting or exceeding the expectations of being #{article} ", tag.strong(name) ])
  end

  def assignment_survey_relevant_prompt(name)
    article = assignment_survey_indefinite_article(name)
    safe_join([ "The outcomes of being #{article} ", tag.strong(name), " represents a real business need for the team and therefore company success." ])
  end
end
