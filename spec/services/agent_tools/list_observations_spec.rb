# frozen_string_literal: true

require "rails_helper"

RSpec.describe AgentTools::ListObservations, type: :service do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, :assigned_employee, person: person, organization: organization) }
  let(:context) do
    AgentTools::Context.new(
      organization: organization,
      person: person,
      company_teammate: teammate
    )
  end
  let(:ability) { create(:ability, company: organization, name: "Software Investigation") }
  let!(:recent_ogo) do
    create(
      :observation,
      :published,
      :public_to_company,
      observer: person,
      company: organization,
      story: "Recent collaboration win",
      observation_type: :kudos,
      observed_at: 2.days.ago
    )
  end
  let!(:old_ogo) do
    create(
      :observation,
      :published,
      :public_to_company,
      observer: person,
      company: organization,
      story: "Old note from last year",
      observation_type: :feedback,
      observed_at: 400.days.ago
    )
  end

  before do
    create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    create(:observation_rating, observation: recent_ogo, rateable: ability, rating: :agree)
  end

  it "lists published observations with thin rows" do
    result = described_class.call(context: context)

    expect(result.ok?).to be(true), -> { result.error.inspect }
    paths = result.data[:observations].map { |row| row[:path] }
    expect(paths).to include(AgentTools::RecordPaths.observation_path(context, recent_ogo))
    expect(result.data[:observations].first).to include(:story_preview, :path, :observer_name)
    expect(result.data[:observations].first).not_to have_key(:story)
  end

  it "filters by timeframe" do
    result = described_class.call(context: context, timeframe: "this_month")

    expect(result.ok?).to be(true)
    paths = result.data[:observations].map { |row| row[:path] }
    expect(paths).to include(AgentTools::RecordPaths.observation_path(context, recent_ogo))
    expect(paths).not_to include(AgentTools::RecordPaths.observation_path(context, old_ogo))
  end

  it "filters by rateable_path" do
    path = AgentTools::RecordPaths.ability_path(context, ability)
    result = described_class.call(context: context, rateable_path: path)

    expect(result.ok?).to be(true), -> { result.error.inspect }
    paths = result.data[:observations].map { |row| row[:path] }
    expect(paths).to eq([AgentTools::RecordPaths.observation_path(context, recent_ogo)])
    expect(result.data[:filters]).to include(rateable_type: "Ability", rateable_id: ability.id)
  end

  it "filters by observation_type" do
    result = described_class.call(context: context, observation_type: "feedback")

    expect(result.ok?).to be(true)
    paths = result.data[:observations].map { |row| row[:path] }
    expect(paths).to eq([AgentTools::RecordPaths.observation_path(context, old_ogo)])
  end

  it "errors on invalid timeframe" do
    result = described_class.call(context: context, timeframe: "last_week")
    expect(result.ok?).to be(false)
    expect(result.error_code).to eq("validation_failed")
  end
end
