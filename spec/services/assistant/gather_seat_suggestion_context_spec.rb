# frozen_string_literal: true

require "rails_helper"

RSpec.describe Assistant::GatherSeatSuggestionContext, type: :service do
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
  let(:major) { create(:position_major_level, major_level: 2, set_name: "Base-#{SecureRandom.hex(4)}") }
  let(:level) { create(:position_level, position_major_level: major, level: "2.1") }
  let(:title) { create(:title, company: organization, position_major_level: major, external_title: "Account Executive") }
  let!(:position) { create(:position, title: title, position_level: level) }
  let!(:assignment) { create(:assignment, company: organization, title: "Pipeline Driver") }
  let!(:other_assignment) { create(:assignment, company: organization, title: "Customer Analytics Owner") }

  before do
    create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    create(
      :position_assignment,
      :required,
      position: position,
      assignment: assignment,
      min_estimated_energy: 40,
      max_estimated_energy: 40
    )
  end

  it "includes an assignment catalog and hydrates assignments for titles mentioned in conversation" do
    result = described_class.call(
      context: context,
      query: "senior version of that role",
      conversation_text: "We need a senior Account Executive. Use the assignments on that position."
    )

    expect(result[:context_note]).to include("Prefer existing Assignments")
    catalog = result[:assignment_catalog]
    expect(catalog[:error]).to be_blank
    titles = Array(catalog[:assignments]).map { |row| row[:title] }
    expect(titles).to include("Pipeline Driver", "Customer Analytics Owner")

    mentioned = result[:titles_mentioned_in_conversation]
    expect(mentioned.map { |row| row[:title] }).to include("Account Executive")

    referenced = result[:referenced_positions_with_assignments]
    expect(referenced).not_to be_empty
    assignment_titles = referenced.flat_map { |pos|
      Array(pos[:assignments]).map { |link| link[:title] }
    }
    expect(assignment_titles).to include("Pipeline Driver")
  end

  it "still returns catalog assignments when the latest message is vague" do
    result = described_class.call(
      context: context,
      query: "those assignments",
      conversation_text: "those assignments"
    )

    catalog_titles = Array(result.dig(:assignment_catalog, :assignments)).map { |row| row[:title] }
    expect(catalog_titles).to include("Pipeline Driver")
  end
end
