# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Organizations::DepartmentsHealth", type: :request do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let!(:teammate) { create(:teammate, person: person, organization: organization, can_manage_maap: true) }
  let(:major_level) { create(:position_major_level) }
  let(:department) { create(:department, company: organization, name: "Engineering") }

  before do
    sign_in_as_teammate_for_request(person, organization)
  end

  describe "GET /departments_health" do
    it "renders Departments Health with object lens, table, and page help" do
      title = create(:title, company: organization, department: department, position_major_level: major_level, external_title: "Engineer")
      TitleExpectationAlignmentScore.create!(
        title: title,
        organization: organization,
        score: 80,
        cells: [],
        path_clarity: true,
        calculated_at: Time.current
      )

      get organization_departments_health_path(organization)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Departments Health")
      expect(response.body).to include("departmentsHealthPageHelp")
      expect(response.body).to include("Goal of this page")
      expect(response.body).to include("Switch object")
      expect(response.body).to include(organization_departments_path(organization))
      expect(response.body).to include(organization_insights_departments_path(organization))
      expect(response.body).to include("Engineering")
      expect(response.body).to include("Combined")
      expect(response.body).to include("Refresh all")
    end
  end

  describe "POST /departments_health_refresh_all" do
    it "enqueues title, position, and assignment EAS refreshes" do
      title = create(:title, company: organization, department: department, position_major_level: major_level, external_title: "Engineer")
      position_level = create(:position_level, position_major_level: major_level, level: "1.1")
      position = create(:position, title: title, position_level: position_level)
      assignment = create(:assignment, company: organization, department: department)

      expect {
        post organization_departments_health_refresh_all_path(organization)
      }.to have_enqueued_job(TitleExpectationAlignmentScoreRefreshJob).with(title.id)
        .and have_enqueued_job(PositionExpectationAlignmentScoreRefreshJob).with(position.id)
        .and have_enqueued_job(AssignmentExpectationAlignmentScoreRefreshJob).with(assignment.id)

      expect(response).to redirect_to(organization_departments_health_path(organization))
    end
  end
end
