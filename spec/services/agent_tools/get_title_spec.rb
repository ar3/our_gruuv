# frozen_string_literal: true

require "rails_helper"

RSpec.describe AgentTools::GetTitle, type: :service do
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
  let!(:title) { create(:title, company: organization, position_major_level: major, external_title: "Engineer") }
  let!(:position) { create(:position, title: title, position_level: level) }

  before do
    create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
  end

  it "returns title with child positions and carrier note" do
    path = AgentTools::RecordPaths.title_path(context, title)
    result = described_class.call(context: context, path: path)

    expect(result.ok?).to be(true)
    expect(result.data[:note]).to include("Titles do not carry Assignments")
    expect(result.data[:title][:carries_assignments]).to be(false)
    expect(result.data[:title][:positions].map { |p| p[:display_name] }).to include(position.display_name)
  end
end
