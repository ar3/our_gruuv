# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Organizations::Insights seats", type: :request do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let!(:teammate) { create(:teammate, person: person, organization: organization, first_employed_at: 1.year.ago) }
  let(:major_level) { create(:position_major_level) }
  let(:department) { create(:department, company: organization, name: "Engineering") }

  before do
    sign_in_as_teammate_for_request(person, organization)
  end

  it "renders seat analytics with six-state pie and both department charts" do
    create(:seat, :draft, title: create(:title, company: organization, position_major_level: major_level, department: department, external_title: "Seat Title"), seat_needed_by: Date.current)

    get organization_insights_seats_path(organization)

    expect(response).to have_http_status(:success)
    expect(response.body).to include("Insights: Seats")
    expect(response.body).to include("Seats Analytics")
    expect(response.body).to include("seats-by-state-chart")
    expect(response.body).to include("seats-by-department-chart")
    expect(response.body).to include("seats-pipeline-by-department-chart")
    expect(response.body).to include("waitForHighcharts")
    expect(response.body).to include("turbo:load")
    expect(response.body).to include("Considered, Open & Filled by Department")
    expect(response.body).to include("Draft, Closed & Archived by Department")
    expect(response.body).to include('"name":"Draft"')
    expect(response.body).to include('"name":"Considered"')
    expect(response.body).to include('"name":"Open"')
    expect(response.body).to include('"name":"Filled"')
    expect(response.body).to include('"name":"Closed"')
    expect(response.body).to include('"name":"Archived"')
  end
end
