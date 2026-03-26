require 'rails_helper'

RSpec.describe 'Company teammate complete_picture page', type: :request do
  let(:organization) { create(:organization) }
  let(:manager) { create(:person) }
  let(:manager_teammate) { create(:teammate, :employment_manager, person: manager, organization: organization) }
  let(:employee) { create(:person, preferred_name: 'Sam C.', first_name: 'Samantha', last_name: 'Cartwright') }
  let(:employee_teammate) { create(:teammate, person: employee, organization: organization) }
  let(:assignment) { create(:assignment, company: organization, title: 'Build Widget') }

  before do
    create(:employment_tenure, teammate: manager_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    create(:employment_tenure, teammate: employee_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    manager_teammate.update!(first_employed_at: 1.year.ago)
    employee_teammate.update!(first_employed_at: 1.year.ago)
    sign_in_as_teammate_for_request(manager, organization)
  end

  describe 'GET /organizations/:organization_id/company_teammates/:id/complete_picture' do
    context 'with an active assignment tenure and finalized check-in' do
      before do
        create(:assignment_tenure, teammate: employee_teammate, assignment: assignment)
        create(:assignment_check_in, :finalized, teammate: employee_teammate, assignment: assignment,
                                                 employee_personal_alignment: 'love')
      end

      it 'shows the employee casual name and assignment check-in link' do
        get complete_picture_organization_company_teammate_path(organization, employee_teammate)
        expect(response).to have_http_status(:success)
        expect(response.body).to include('Sam C.')
        expect(response.body).to include('Assignment check-in')
        expect(response.body).to include(organization_teammate_assignment_path(organization, employee_teammate, assignment))
        expect(response.body).not_to include('View Assignment')
        expect(response.body).not_to include('Manage Tenures')
      end

      it 'includes check-in summary popover markup for the three sentences' do
        get complete_picture_organization_company_teammate_path(organization, employee_teammate)
        expect(response.body).to include('data-bs-toggle="popover"')
        expect(response.body).to include('Love')
      end
    end
  end
end
