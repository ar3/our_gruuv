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

  def assignment_survey_quality_signal(distribution)
    AssignmentSurveys::QualitySignal.from_distribution(distribution)
  end

  def assignment_survey_quality_popover_content(signal)
    return "" if signal.blank?

    parts = [
      tag.p(class: "mb-2") { tag.strong("OG thinks this is #{signal.label}.") },
      tag.p(class: "mb-2 small text-muted") do
        "This average sits in #{signal.territory} territory (#{signal.range_description})."
      end,
      dissent_popover_paragraph(signal)
    ]
    parts << small_sample_popover_paragraph(signal) if signal.small_sample?
    safe_join(parts)
  end

  def assignment_survey_quality_aria_label(signal, dimension_title: nil)
    return "No average yet" if signal.blank?

    prefix = dimension_title.present? ? "#{dimension_title}: " : ""
    parts = [ "#{prefix}OG thinks this is #{signal.label}" ]
    parts << "with dissenting responses" if signal.show_caution?
    parts << "small sample" if signal.small_sample?
    parts << "hover or focus for details"
    parts.join(", ")
  end

  private

  def dissent_popover_paragraph(signal)
    if signal.show_caution?
      tag.p(class: "mb-2") do
        "However, #{pluralize(signal.dissent_count, 'response')} on the disagree side " \
          "(ratings 1–3). That dissent can't be overlooked."
      end
    elsif signal.dissent_count.positive?
      tag.p(class: "mb-2") do
        "#{pluralize(signal.dissent_count, 'response')} on the disagree side (ratings 1–3)."
      end
    else
      tag.p(class: "mb-2 small text-muted") do
        "No responses on the disagree side (ratings 1–3)."
      end
    end
  end

  def small_sample_popover_paragraph(signal)
    tag.p(class: "mb-0 small") do
      "Small sample: only #{pluralize(signal.total, 'response')}. " \
        "Treat this as an early signal, not a steady verdict."
    end
  end
end

