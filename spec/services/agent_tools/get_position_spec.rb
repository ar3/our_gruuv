# frozen_string_literal: true

require "rails_helper"

RSpec.describe AgentTools::GetPosition, type: :service do
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
  let(:level) { create(:position_level, position_major_level: major, level: "2.2") }
  let(:title) { create(:title, company: organization, position_major_level: major, external_title: "Engineer") }
  let!(:position) { create(:position, title: title, position_level: level) }

  before do
    create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    create(
      :position_assignment,
      :required,
      position: position,
      assignment: create(:assignment, company: organization, title: "Ship Features"),
      min_estimated_energy: 50,
      max_estimated_energy: 50
    )
  end

  it "returns the position with assignments by path" do
    path = AgentTools::RecordPaths.position_path(context, position)
    result = described_class.call(context: context, path: path)

    expect(result.ok?).to be(true)
    expect(result.data[:position][:display_name]).to eq(position.display_name)
    expect(result.data[:position][:assignments].size).to eq(1)
    expect(result.data[:position][:assignments].first).to include(
      title: "Ship Features",
      assignment_type: "required",
      min_estimated_energy: 50,
      max_estimated_energy: 50
    )
  end

  it "errors when path missing" do
    result = described_class.call(context: context)
    expect(result.ok?).to be(false)
    expect(result.error_code).to eq("validation_failed")
  end
end
