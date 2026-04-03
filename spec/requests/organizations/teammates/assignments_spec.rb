# frozen_string_literal: true

require "rails_helper"

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
    end
  end
end
