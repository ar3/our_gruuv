# frozen_string_literal: true

require "rails_helper"

RSpec.describe PossibleObservationSlackSearches::SubjectContextPack do
  let(:organization) { create(:organization) }
  let(:teammate) { create(:company_teammate, organization: organization) }

  before do
    create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    teammate.update!(first_employed_at: 1.year.ago)
  end

  it "includes aspirations, assignment outcomes, abilities, and goals with catalog ids" do
    aspiration = create(:aspiration, company: organization, name: "Delight customers", description: "Put customers first")
    assignment = create(:assignment, company: organization, title: "Own launch")
    create(:assignment_outcome, assignment: assignment, description: "Ship launch on time")
    create(:assignment_tenure, teammate: teammate, assignment: assignment, started_at: 1.month.ago, ended_at: nil, anticipated_energy_percentage: 50)
    ability = create(:ability, company: organization, name: "Facilitation", description: "Run effective meetings")
    create(:assignment_ability, assignment: assignment, ability: ability, milestone_level: 3)
    goal = create(
      :goal,
      company: organization,
      owner: teammate,
      creator: teammate,
      title: "Close Q3 deals",
      description: "Hit quota",
      started_at: 1.day.ago,
      completed_at: nil
    )

    result = described_class.call(teammate: teammate, organization: organization)

    expect(result.prompt_text).to include("Delight customers")
    expect(result.prompt_text).to include("Ship launch on time")
    expect(result.prompt_text).to include("Facilitation")
    expect(result.prompt_text).to include("Close Q3 deals")
    expect(result.prompt_text).not_to include("handbook")
    expect(result.catalog["Aspiration"][aspiration.id]).to eq("Delight customers")
    expect(result.catalog["Assignment"][assignment.id]).to eq("Own launch")
    expect(result.catalog["Ability"][ability.id]).to eq("Facilitation")
    expect(result.catalog["Goal"][goal.id]).to eq("Close Q3 deals")
  end
end
