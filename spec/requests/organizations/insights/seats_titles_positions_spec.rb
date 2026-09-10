# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Organizations::Insights seats_titles_positions title paths", type: :request do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let!(:teammate) { create(:teammate, person: person, organization: organization, first_employed_at: 1.year.ago) }
  let(:major_level) { create(:position_major_level) }
  let(:department) { create(:department, company: organization, name: "Engineering") }

  before do
    sign_in_as_teammate_for_request(person, organization)
  end

  it "renders title paths section with counts, health link, and department filter" do
    create(:title, company: organization, position_major_level: major_level, department: department, external_title: "Engineer", end_cap: true)
    orphan = create(:title, company: organization, position_major_level: major_level, department: department, external_title: "Orphan")
    linked = create(:title, company: organization, position_major_level: major_level, department: department, external_title: "Linked")
    create(:title_path, from_title: linked, to_title: create(:title, company: organization, position_major_level: major_level, department: department, external_title: "Dest"))

    get organization_insights_seats_titles_positions_path(organization)

    expect(response).to have_http_status(:success)
    expect(response.body).to include("Title paths")
    expect(response.body).to include("Position Titles that have a path defined")
    expect(response.body).to include("Position Health")
    expect(response.body).to include(organization_positions_health_path(organization))
    expect(response.body).to include("insights-title-paths-graph")
    expect(response.body).to include("All departments")
    expect(response.body).to include("Engineering")
    expect(response.body).to include("Natural progression")
    expect(response.body).to include("Cytoscape")
    expect(response.body).to include("G6")
    expect(response.body).to include("L1")
    expect(response.body).to include("Linked")
    expect(response.body).to include("Drag nodes to rearrange")
    expect(response.body).not_to include("\"label\":\"Orphan")
  end

  it "filters the graph by department_id" do
    other = create(:department, company: organization, name: "Sales")
    eng = create(:title, company: organization, position_major_level: major_level, department: department, external_title: "Eng Only")
    sales = create(:title, company: organization, position_major_level: major_level, department: other, external_title: "Sales Only")
    create(:title_path, from_title: eng, to_title: create(:title, company: organization, position_major_level: major_level, department: department, external_title: "Eng Dest"))

    get organization_insights_seats_titles_positions_path(organization, department_id: department.id)

    expect(response).to have_http_status(:success)
    expect(response.body).to include("Eng Only")
    expect(response.body).not_to include("Sales Only")
  end
end
