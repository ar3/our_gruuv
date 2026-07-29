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

  def assignment_survey_rating_set_popover_content(teammate_count:, assignment_count:)
    safe_join(
      [
        tag.div("#{pluralize(teammate_count, 'teammate')} make up these responses"),
        tag.div("#{pluralize(assignment_count, 'assignment')} represented")
      ]
    )
  end
end
