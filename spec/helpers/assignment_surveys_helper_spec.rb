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

  it "builds an expectation alignment blurb with the assignment title bolded" do
    band = AssignmentSurveys::ExpectationAlignmentScore.band_for_score(96)
    assignment = build(:assignment, title: "Growth Buddy")
    blurb = helper.expectation_alignment_score_blurb(band, assignment)

    expect(blurb).to include("Congrats!")
    expect(blurb).to include("<strong>Growth Buddy</strong>")
    expect(blurb).to include("expectation alignment")
    expect(blurb).to be_html_safe
  end

  it "escapes HTML in assignment titles inside expectation alignment blurbs" do
    band = AssignmentSurveys::ExpectationAlignmentScore.band_for_score(10)
    assignment = build(:assignment, title: "<script>x</script>")
    blurb = helper.expectation_alignment_score_blurb(band, assignment)

    expect(blurb).not_to include("<script>")
    expect(blurb).to include("We have work to do!")
  end
end
