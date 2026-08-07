require "rails_helper"

RSpec.describe AssignmentSurveysHelper, type: :helper do
  it "chooses the article based on the assignment name" do
    expect(helper.assignment_survey_indefinite_article("Product Manager")).to eq("a")
    expect(helper.assignment_survey_indefinite_article("Engineer")).to eq("an")
  end

  it "bolds the assignment name inside each prompt" do
    prompt = helper.assignment_survey_understandable_prompt("Growth Buddy")
    expect(prompt).to include("relied on to be a <strong>Growth Buddy</strong>")
    expect(prompt).to be_html_safe

    expect(helper.assignment_survey_possible_prompt("Engineer")).to include("being an <strong>Engineer</strong>")
    expect(helper.assignment_survey_relevant_prompt("Engineer")).to include("The outcomes of being an <strong>Engineer</strong> represents")
  end

  it "escapes HTML in assignment names" do
    prompt = helper.assignment_survey_understandable_prompt("<script>x</script>")
    expect(prompt).not_to include("<script>")
  end

  it "describes teammates and assignments in a rating-set popover" do
    content = helper.assignment_survey_rating_set_popover_content(teammate_count: 2, assignment_count: 3)
    expect(content).to include("2 teammates make up these responses")
    expect(content).to include("3 assignments represented")
    expect(content).to be_html_safe
  end

  it "builds an opinionated quality popover with dissent and small-sample notes" do
    signal = AssignmentSurveys::QualitySignal.from_distribution(
      average: 5.2,
      counts: { 1 => 1, 2 => 0, 3 => 0, 4 => 0, 5 => 1, 6 => 0 },
      total: 2
    )
    content = helper.assignment_survey_quality_popover_content(signal)

    expect(content).to include("OG thinks this is Healthy.")
    expect(content).to include("However, 1 response on the disagree side")
    expect(content).to include("Small sample: only 2 responses")
    expect(content).to be_html_safe
    expect(helper.assignment_survey_quality_aria_label(signal, dimension_title: "Possible"))
      .to include("Possible: OG thinks this is Healthy")
      .and include("with dissenting responses")
      .and include("small sample")
  end
end
