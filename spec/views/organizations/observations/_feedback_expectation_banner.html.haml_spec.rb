# frozen_string_literal: true

require "rails_helper"

RSpec.describe "organizations/observations/_feedback_expectation_banner", type: :view do
  let(:company) { create(:organization, :company) }
  let(:observer) { create(:person, first_name: "Observer", last_name: "Person") }
  let(:observation) do
    create(:observation, observer: observer, company: company, observation_type: :feedback, created_as_type: "feedback")
  end

  before do
    assign(:organization, company)
    assign(:observation, observation)
    allow(view).to receive(:policy).with(observation).and_return(double(update?: true))
    allow(view).to receive(:edit_organization_observation_path).and_return("/edit")
    allow(view).to receive(:organization_observation_path).and_return("/show")
    allow(view).to receive(:convert_to_kudos_organization_observation_path).and_return("/convert-kudos")
    allow(view).to receive(:convert_to_generic_organization_observation_path).and_return("/convert-generic")
  end

  it "explains the feedback expectation and offers actions" do
    render partial: "organizations/observations/feedback_expectation_banner", locals: { organization: company }

    expect(rendered).to include("Feedback needs a constructive rating")
    expect(rendered).to include("Mis-aligned")
    expect(rendered).to include("Concerning")
    expect(rendered).to have_link("Edit", href: "/edit")
    expect(rendered).to have_button("Change to Kudos")
    expect(rendered).to have_button("Change to Generic")
  end
end
