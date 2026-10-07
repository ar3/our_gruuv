# frozen_string_literal: true

require "rails_helper"

RSpec.describe AgentTools::GetObservation, type: :service do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, :assigned_employee, person: person, organization: organization) }
  let(:observee_person) { create(:person) }
  let(:observee) { create(:teammate, person: observee_person, organization: organization) }
  let(:context) do
    AgentTools::Context.new(
      organization: organization,
      person: person,
      company_teammate: teammate
    )
  end
  let(:ability) { create(:ability, company: organization, name: "Software Investigation") }
  let(:assignment) { create(:assignment, company: organization, title: "Engineering Flow") }
  let(:observation) do
    create(
      :observation,
      :published,
      :public_to_company,
      observer: person,
      company: organization,
      story: "Full story about collaboration on the launch",
      observation_type: :kudos,
      primary_feeling: "appreciated",
      secondary_feeling: "confident"
    )
  end

  before do
    create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    create(:employment_tenure, teammate: observee, company: organization, started_at: 1.year.ago, ended_at: nil)
    observation.observees.destroy_all
    Observations::AddObserveeService.new(observation: observation, teammate_id: observee.id).call
    create(:observation_rating, observation: observation, rateable: ability, rating: :strongly_agree)
    create(:observation_rating, observation: observation, rateable: assignment, rating: :agree)
  end

  it "returns a fully hydrated observation" do
    path = AgentTools::RecordPaths.observation_path(context, observation)
    result = described_class.call(context: context, path: path)

    expect(result.ok?).to be(true), -> { result.error.inspect }
    row = result.data[:observation]
    expect(row[:story]).to eq("Full story about collaboration on the launch")
    expect(row[:observation_type]).to eq("kudos")
    expect(row[:privacy_level]).to eq("public_to_company")
    expect(row[:draft]).to be(false)
    expect(row[:primary_feeling]).to eq("appreciated")
    expect(row[:feelings_display]).to be_present
    expect(row[:observer]).to include(
      name: person.display_name,
      path: AgentTools::RecordPaths.teammate_path(context, teammate)
    )
    expect(row[:observees]).to contain_exactly(
      hash_including(
        name: observee_person.display_name,
        path: AgentTools::RecordPaths.teammate_path(context, observee)
      )
    )
    expect(row[:ratings]).to contain_exactly(
      hash_including(
        rateable_type: "Ability",
        rateable_id: ability.id,
        name: "Software Investigation",
        path: AgentTools::RecordPaths.ability_path(context, ability),
        rating: "strongly_agree",
        rating_label: "Exceptional"
      ),
      hash_including(
        rateable_type: "Assignment",
        rateable_id: assignment.id,
        name: "Engineering Flow",
        path: AgentTools::RecordPaths.assignment_path(context, assignment),
        rating: "agree",
        rating_label: "Strong"
      )
    )
    expect(row[:path]).to eq(path)
  end

  it "errors when path missing" do
    result = described_class.call(context: context)
    expect(result.ok?).to be(false)
    expect(result.error_code).to eq("validation_failed")
  end

  it "errors when observation is not visible" do
    other = create(:person)
    private_ogo = create(
      :observation,
      :published,
      :observer_only,
      observer: other,
      company: organization,
      story: "Private journal"
    )
    path = AgentTools::RecordPaths.observation_path(context, private_ogo)
    result = described_class.call(context: context, path: path)

    expect(result.ok?).to be(false)
    expect(result.error_code).to eq("not_authorized")
  end
end
