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
        expect(response.body).to include('Next check-in:')
        expect(response.body).to include(organization_company_teammate_check_ins_path(organization, employee_teammate))
        expect(response.body).to include('Sam C.')
        expect(response.body).to include('True Day-to-Day')
        expect(response.body).to include('real job description')
        expect(response.body).not_to include('Complete Picture View')
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

    context 'with department, manager, observations, and goals on the profile teammate' do
      let(:department) { create(:department, company: organization, name: 'Engineering Dept') }
      let(:employee_position) { employee_teammate.employment_tenures.find_by(ended_at: nil).position }

      before do
        employee_position.title.update!(department: department)
        employee_teammate.employment_tenures.find_by(ended_at: nil).update!(manager_teammate: manager_teammate)

        obs = build(:observation, :public_to_company, company: organization, observer: employee, published_at: Time.current)
        obs.observees.clear
        obs.observees.build(teammate: manager_teammate)
        obs.save!

        create(:goal, owner: employee_teammate, creator: employee_teammate, started_at: Time.current, company: organization)
      end

      it 'renders the 8/4 layout, spotlight, department and manager links, growth, and observations card' do
        get complete_picture_organization_company_teammate_path(organization, employee_teammate)
        expect(response).to have_http_status(:success)

        expect(response.body).to include('col-lg-8')
        expect(response.body).to include('col-lg-4')
        expect(response.body).to include('Spotlight')
        expect(response.body).to match(/total position/i)
        expect(response.body).to include('held at')
        expect(response.body).to include(organization.display_name)
        expect(response.body).to include(organization_seats_path(organization))

        expect(response.body).to include('Department:')
        expect(response.body).to include('Engineering Dept')
        expect(response.body).to include(organization_department_path(organization, department))

        expect(response.body).to include('Manager:')
        expect(response.body).to include(internal_organization_company_teammate_path(organization, manager_teammate))

        expect(response.body).to include('Position Level')
        expect(response.body).to include('Earliest start day:')
        expect(response.body).to include('In this position since:')

        expect(response.body).to include(organization_position_path(organization, employee_position))

        expect(response.body).to include('Next check-in:')
        expect(response.body).to include(organization_company_teammate_check_ins_path(organization, employee_teammate))

        expect(response.body).to include(my_growth_goals_organization_company_teammate_path(organization, employee_teammate))
        expect(response.body).to include('Growth:')
        expect(response.body).to match(/1 active goal/i)

        expect(response.body).to include('Observations')
        expect(response.body).to match(/given/)
        expect(response.body).to match(/received/)
        expect(response.body).to include("involving_teammate_id=#{employee_teammate.id}")
        expect(response.body).to include('All observations involving this teammate')
      end
    end
  end
end
