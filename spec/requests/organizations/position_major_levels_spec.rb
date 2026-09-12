# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Organizations::PositionMajorLevels", type: :request do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:department) { create(:department, company: organization, name: "Engineering") }
  let(:major) { create(:position_major_level, set_name: "Base 10x3", major_level: 2, description: "Mid Career") }
  let!(:level_1) { create(:position_level, position_major_level: major, level: "2.1", ideal_assignment_goal_types: "70% Activities") }
  let!(:level_2) { create(:position_level, position_major_level: major, level: "2.2", ideal_assignment_goal_types: "50% Activities") }
  let!(:title) do
    create(:title, company: organization, position_major_level: major, external_title: "Analyst", department: department)
  end
  let!(:position) { create(:position, title: title, position_level: level_1) }

  before do
    create(:teammate, person: person, organization: organization)
    sign_in_as_teammate_for_request(person, organization)
  end

  describe "GET /organizations/:organization_id/position_major_levels" do
    it "lists majors, minors, and org title/position counts with links" do
      get organization_position_major_levels_path(organization)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Position levels")
      expect(response.body).to include("positionLevelsPageHelp")
      expect(response.body).to include("L:2.*")
      expect(response.body).to include("Mid Career")
      expect(response.body).to include("Base 10x3")
      expect(response.body).to include(organization_position_level_set_path(organization, "Base 10x3"))
      expect(response.body).to include("2.1")
      expect(response.body).to include("Emerging / starting salary")
      expect(response.body).to include("70% Activities")
      expect(response.body).to include("2.2")
      expect(response.body).to include("Established / solid experience")
      expect(response.body).to include("50% Activities")
      expect(response.body).to include("1 title")
      expect(response.body).to include("1 position")
      expect(response.body).to include("0 positions")
      expect(response.body).to include("Analyst")
      expect(response.body).to include("Engineering")
      expect(response.body).to include(organization_title_path(organization, title))
      expect(response.body).to include(organization_department_path(organization, department))
      expect(response.body).to include(organization_position_path(organization, position))
      expect(response.body).to include(position.display_name)
      expect(response.body).to match(/Department.*Title/m)
      expect(response.body).to match(/Department.*Position/m)
    end

    it "sorts expanded titles and positions by department then name" do
      sales = create(:department, company: organization, name: "Sales")
      eng_z = create(:title, company: organization, position_major_level: major,
                     external_title: "Zed Engineer", department: department)
      sales_a = create(:title, company: organization, position_major_level: major,
                       external_title: "Account Exec", department: sales)
      create(:position, title: eng_z, position_level: level_1)
      create(:position, title: sales_a, position_level: level_1)

      get organization_position_major_levels_path(organization)

      expect(response).to have_http_status(:success)
      expect(response.body.index("Engineering")).to be < response.body.index("Sales")
      expect(response.body.index("Analyst")).to be < response.body.index("Zed Engineer")
      expect(response.body.index("Account Exec")).to be > response.body.index("Zed Engineer")
    end

    it "does not include titles or positions from other organizations" do
      other_org = create(:organization)
      other_title = create(:title, company: other_org, position_major_level: major, external_title: "Other Org Title")
      create(:position, title: other_title, position_level: level_1)

      get organization_position_major_levels_path(organization)

      expect(response).to have_http_status(:success)
      expect(response.body).not_to include("Other Org Title")
      expect(response.body).to include("1 title")
      expect(response.body).to include("1 position")
    end
  end

  describe "GET /organizations/:organization_id/position_major_levels/:id" do
    it "lists position levels and titles for the major level without set name" do
      get organization_position_major_level_path(organization, major)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("L:2.*")
      expect(response.body).to include("Mid Career")
      expect(response.body).to include("2.1")
      expect(response.body).to include("2.2")
      expect(response.body).to include("Analyst")
      expect(response.body).to include(organization_title_path(organization, title))
      expect(response.body).to include(organization_position_major_levels_path(organization))
      expect(response.body).not_to include("Base 10x3")
    end
  end
end
