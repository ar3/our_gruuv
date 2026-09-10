# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Organizations::Employees index other actions", type: :request do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }

  before do
    sign_in_as_teammate_for_request(person, organization)
  end

  it "shows enabled company teammates download for employment managers" do
    teammate = person.company_teammates.find_by!(organization: organization)
    teammate.update!(can_manage_employment: true, first_employed_at: 1.year.ago, last_terminated_at: nil)

    get organization_employees_path(organization)

    expect(response).to have_http_status(:success)
    expect(response.body).to include("Other actions")
    expect(response.body).to include("Download company teammates (CSV)")
    expect(response.body).to include(download_organization_bulk_downloads_path(organization, type: "company_teammates"))
    expect(response.body).not_to include("Requires employment management permission")
  end

  it "shows disabled download with permission warning when lacking manage employment" do
    teammate = person.company_teammates.find_by!(organization: organization)
    teammate.update!(can_manage_employment: false, first_employed_at: 1.year.ago, last_terminated_at: nil)

    get organization_employees_path(organization)

    expect(response).to have_http_status(:success)
    expect(response.body).to include("Other actions")
    expect(response.body).to include("Download company teammates (CSV)")
    expect(response.body).to include("Requires employment management permission")
    expect(response.body).to include("bi-exclamation-triangle")
  end
end
