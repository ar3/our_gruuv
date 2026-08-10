# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Company teammate True JD print view', type: :request do
  let(:organization) { create(:organization) }
  let(:manager) { create(:person) }
  let(:manager_teammate) { create(:teammate, :employment_manager, person: manager, organization: organization) }
  let(:employee) { create(:person, preferred_name: 'Sam C.', first_name: 'Samantha', last_name: 'Cartwright') }
  let(:employee_teammate) { create(:teammate, person: employee, organization: organization) }
  let(:peer) { create(:person) }
  let(:peer_teammate) { create(:teammate, person: peer, organization: organization) }
  let(:required_assignment) { create(:assignment, company: organization, title: 'Close Deals') }
  let(:optional_assignment) { create(:assignment, company: organization, title: 'Run Guild') }
  let(:unique_assignment) { create(:assignment, company: organization, title: 'Special Project') }

  before do
    create(:employment_tenure, teammate: manager_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    create(:employment_tenure, teammate: employee_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    create(:employment_tenure, teammate: peer_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    manager_teammate.update!(first_employed_at: 1.year.ago)
    employee_teammate.update!(first_employed_at: 1.year.ago)
    peer_teammate.update!(first_employed_at: 1.year.ago)
  end

  describe 'GET /organizations/:organization_id/company_teammates/:id/true_jd_print' do
    context 'when the viewer is an active peer (internal-style access)' do
      before do
        position = employee_teammate.employment_tenures.find_by(ended_at: nil).position
        create(:position_assignment, position: position, assignment: required_assignment, assignment_type: 'required',
                                     min_estimated_energy: 10, max_estimated_energy: 30)
        create(:position_assignment, position: position, assignment: optional_assignment, assignment_type: 'suggested',
                                     min_estimated_energy: 0, max_estimated_energy: 15)
        create(:assignment_tenure, teammate: employee_teammate, assignment: required_assignment,
                                   anticipated_energy_percentage: 25)
        create(:assignment_tenure, teammate: employee_teammate, assignment: optional_assignment,
                                   anticipated_energy_percentage: 12)
        create(:assignment_tenure, teammate: employee_teammate, assignment: unique_assignment,
                                   anticipated_energy_percentage: 8)
        sign_in_as_teammate_for_request(peer, organization)
      end

      it 'renders the print True JD with exact energy and expanded optionals' do
        get true_jd_print_organization_company_teammate_path(organization, employee_teammate)
        expect(response).to have_http_status(:success)
        expect(response.body).to include('True JD (print view)')
        expect(response.body).to include('Sam C.')
        expect(response.body).to include('actual current job description')
        expect(response.body).to include('blueprint')
        expect(response.body).to include(job_description_organization_position_path(organization, employee_teammate.employment_tenures.find_by(ended_at: nil).position))
        expect(response.body).to include('Required Assignments')
        expect(response.body).to include('Optional / Elective / Uniquely-You Assignments')
        expect(response.body).to include('Close Deals')
        expect(response.body).to include('Run Guild')
        expect(response.body).to include('Special Project')
        expect(response.body).to include('(25% of your energy)')
        expect(response.body).to include('(12% of your energy)')
        expect(response.body).to include('(8% of your energy)')
        expect(response.body).not_to include('Show the')
        expect(response.body).not_to include('likely')
        expect(response.body).to include('Employee Signature')
        expect(response.body).to include('window.print()')
      end
    end

    context 'when the person has no current position' do
      before do
        employee_teammate.employment_tenures.find_by(ended_at: nil)&.destroy!
        create(:assignment_tenure, teammate: employee_teammate, assignment: unique_assignment,
                                   anticipated_energy_percentage: 40)
        sign_in_as_teammate_for_request(peer, organization)
      end

      it 'still shows the actual JD and notes blueprint unavailable' do
        get true_jd_print_organization_company_teammate_path(organization, employee_teammate)
        expect(response).to have_http_status(:success)
        expect(response.body).to include('actual current job description')
        expect(response.body).to include('blueprint is unavailable')
        expect(response.body).to include('Special Project')
        expect(response.body).to include('(40% of your energy)')
      end
    end

    context 'when the viewer is from another organization' do
      let(:other_organization) { create(:organization) }
      let(:outsider) { create(:person) }
      let(:outsider_teammate) { create(:teammate, person: outsider, organization: other_organization) }

      before do
        create(:employment_tenure, teammate: outsider_teammate, company: other_organization, started_at: 1.year.ago, ended_at: nil)
        outsider_teammate.update!(first_employed_at: 1.year.ago)
        sign_in_as_teammate_for_request(outsider, other_organization)
      end

      it 'denies access' do
        get true_jd_print_organization_company_teammate_path(organization, employee_teammate)
        expect(response).not_to have_http_status(:success)
      end
    end
  end
end
