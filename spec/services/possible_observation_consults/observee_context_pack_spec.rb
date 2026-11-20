# frozen_string_literal: true

require "rails_helper"

RSpec.describe PossibleObservationConsults::ObserveeContextPack do
  let(:organization) { create(:organization) }
  let(:person_a) { create(:person, full_name: "Kayla One") }
  let(:person_b) { create(:person, full_name: "Nicole Two") }
  let(:teammate_a) { create(:company_teammate, person: person_a, organization: organization, first_employed_at: 1.year.ago) }
  let(:teammate_b) { create(:company_teammate, person: person_b, organization: organization, first_employed_at: 1.year.ago) }

  it "returns aspirations-only catalog when there are no observees" do
    aspiration = create(:aspiration, company: organization, name: "Customer First")

    pack = described_class.call(teammates: [], organization: organization)

    expect(pack.observee_name).to eq("the team")
    expect(pack.catalog["Aspiration"]).to include(aspiration.id => "Customer First")
    expect(pack.catalog["Assignment"]).to eq({})
    expect(pack.catalog["Ability"]).to eq({})
    expect(pack.prompt_text).to include("no named observee")
  end

  it "intersects shared assignments/abilities across observees" do
    shared_assignment = create(:assignment, company: organization, title: "Shared Launch")
    only_a = create(:assignment, company: organization, title: "Only Kayla")
    shared_ability = create(:ability, company: organization, name: "Shared Craft")
    only_b = create(:ability, company: organization, name: "Only Nicole")

    allow(PossibleObservationSlackSearches::SubjectContextPack).to receive(:call).and_return(
      PossibleObservationSlackSearches::SubjectContextPack::Result.new(
        prompt_text: "A",
        catalog: {
          "Assignment" => { shared_assignment.id => "Shared Launch", only_a.id => "Only Kayla" },
          "Ability" => { shared_ability.id => "Shared Craft" },
          "Aspiration" => {},
          "Goal" => {}
        }
      ),
      PossibleObservationSlackSearches::SubjectContextPack::Result.new(
        prompt_text: "B",
        catalog: {
          "Assignment" => { shared_assignment.id => "Shared Launch" },
          "Ability" => { shared_ability.id => "Shared Craft", only_b.id => "Only Nicole" },
          "Aspiration" => {},
          "Goal" => {}
        }
      )
    )

    pack = described_class.call(teammates: [teammate_a, teammate_b], organization: organization)

    expect(pack.observee_name).to include("Kayla").and include("Nicole")
    expect(pack.catalog["Assignment"].keys).to contain_exactly(shared_assignment.id)
    expect(pack.catalog["Ability"].keys).to contain_exactly(shared_ability.id)
    expect(pack.prompt_text).to include("shared")
  end
end
