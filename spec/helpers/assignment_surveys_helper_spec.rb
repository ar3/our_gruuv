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
end
