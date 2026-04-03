# frozen_string_literal: true

require "rails_helper"
require "nokogiri"

RSpec.describe "Organizations::Teammates::Assignments (1-by-1 check-in page)", type: :request do
  let(:organization) { create(:organization) }
  let(:employee_person) { create(:person) }
  let!(:employee_teammate) { create(:company_teammate, person: employee_person, organization: organization) }
  let(:assignment) { create(:assignment, company: organization, title: "Key Outcome Alpha") }
  let!(:assignment_tenure) do
    create(:assignment_tenure, teammate: employee_teammate, assignment: assignment, anticipated_energy_percentage: 35)
  end

  before do
    create(:employment_tenure, teammate: employee_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    employee_teammate.update!(first_employed_at: 1.year.ago) if employee_teammate.respond_to?(:first_employed_at)
  end

  def assignment_show_path
    organization_teammate_assignment_path(organization, employee_teammate, assignment)
  end

  describe "GET show" do
    context "when latest finalized is crystal clear and the open check-in is fresh on the employee side" do
      let!(:_finalized_assignment_check_in) do
        create(:assignment_check_in, :finalized,
          teammate: employee_teammate,
          assignment: assignment,
          official_check_in_completed_at: 5.days.ago)
      end
      let!(:_open_assignment_check_in) do
        create(:assignment_check_in,
          teammate: employee_teammate,
          assignment: assignment,
          check_in_started_on: Date.current,
          official_check_in_completed_at: nil,
          actual_energy_percentage: 35,
          employee_rating: nil,
          manager_rating: nil,
          official_rating: nil,
          employee_personal_alignment: nil,
          employee_private_notes: nil,
          manager_private_notes: nil,
          shared_notes: nil,
          employee_completed_at: nil,
          manager_completed_at: nil,
          manager_completed_by_teammate: nil,
          finalized_by_teammate: nil)
      end

      before { sign_in_as_teammate_for_request(employee_person, organization) }

      it "shows the crystal-clear banner with assignment title and early check-in link" do
        get assignment_show_path
        expect(response).to have_http_status(:success)
        expect(response.body).to include("crystal clear on where they stand")
        expect(response.body).to include("thinking about them and #{assignment.title}")
        expect(response.body).to include("click here to check in early.")
        expect(response.body).to include("fresh-single-check-in-toggle-#{_open_assignment_check_in.id}")
      end

      it "links current period observations to the observations index with observee and assignment (no timeframe)" do
        get assignment_show_path
        expect(response).to have_http_status(:success)

        doc = Nokogiri::HTML(response.body)
        link = doc.at_xpath("//a[contains(., 'Show all observations involving')]")
        expect(link).to be_present
        expect(link.text).to include(employee_person.casual_name)
        expect(link.text).to include(assignment.title)

        href = link["href"]
        uri = URI.parse(href)
        params = Rack::Utils.parse_nested_query(uri.query)
        expect(uri.path).to eq(organization_observations_path(organization))
        expect(params["observee_ids"]).to eq([employee_teammate.id.to_s])
        expect(params["rateable_type"]).to eq("Assignment")
        expect(params["rateable_id"]).to eq(assignment.id.to_s)
        expect(params["timeframe"]).to be_nil
        expect(params["timeframe_start_date"]).to be_nil
        expect(params["timeframe_end_date"]).to be_nil
        expect(params["return_text"]).to eq("Back to 1-by-1 check-in")
        expect(params["return_url"]).to eq(assignment_show_path)
      end
    end
  end
end
