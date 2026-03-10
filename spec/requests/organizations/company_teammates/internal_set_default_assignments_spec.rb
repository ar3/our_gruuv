require 'rails_helper'

RSpec.describe 'Internal Teammate Page - Set Default Assignments', type: :request do
  let(:organization) { create(:organization) }
  let(:department) { create(:department, company: organization, name: 'Engineering') }
  let(:manager_person) { create(:person) }
  let(:employee_person) { create(:person) }

  let!(:manager_teammate) do
    ct = create(:company_teammate, person: manager_person, organization: organization, can_manage_employment: true)
    CompanyTeammate.find(ct.id)
  end

  let!(:employee_teammate) do
    ct = create(:company_teammate, person: employee_person, organization: organization)
    CompanyTeammate.find(ct.id)
  end

  let!(:employment_tenure) do
    et = create(:employment_tenure,
      teammate: employee_teammate,
      company: organization,
      started_at: 1.month.ago,
      ended_at: nil,
      manager_teammate: manager_teammate)
    et.reload
    et
  end

  let(:position) { employment_tenure.position }
  let!(:required_assignment1) { create(:assignment, company: organization, department: department, title: 'Required One') }
  let!(:required_assignment2) { create(:assignment, company: organization, department: department, title: 'Required Two') }

  before do
    create(:employment_tenure, teammate: manager_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    manager_teammate.update!(first_employed_at: 1.year.ago)
    employee_teammate.update!(first_employed_at: 1.month.ago)
    create(:position_assignment, :required, position: position, assignment: required_assignment1)
    create(:position_assignment, :required, position: position, assignment: required_assignment2)
  end

  describe 'GET internal' do
    context 'when there are required assignments without active tenure' do
      context 'and viewer is in managerial hierarchy (manager)' do
        before { sign_in_as_teammate_for_request(manager_person, organization) }

        it 'shows enabled Set N default assignments button' do
          get internal_organization_company_teammate_path(organization, employee_teammate)
          expect(response).to have_http_status(:success)
          expect(assigns(:required_assignments_without_active_tenure).size).to eq(2)
          expect(assigns(:can_set_default_assignments)).to be true
          expect(response.body).to include('Set 2 default assignments')
          expect(response.body).to include(set_default_assignments_organization_company_teammate_path(organization, employee_teammate))
          expect(response.body).not_to include('data-bs-title')
        end

        it 'does not show disabled button or warning icon' do
          get internal_organization_company_teammate_path(organization, employee_teammate)
          expect(response.body).not_to include('disabled')
          expect(response.body).not_to include('You must be in this teammate\'s managerial hierarchy')
        end
      end

      context 'and viewer has manage_employment permission but is not manager' do
        let!(:hr_person) { create(:person) }
        let!(:hr_teammate) do
          ct = create(:company_teammate, person: hr_person, organization: organization, can_manage_employment: true)
          CompanyTeammate.find(ct.id)
        end

        before do
          create(:employment_tenure, teammate: hr_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
          hr_teammate.update!(first_employed_at: 1.year.ago)
          sign_in_as_teammate_for_request(hr_person, organization)
        end

        it 'shows enabled Set N default assignments button' do
          get internal_organization_company_teammate_path(organization, employee_teammate)
          expect(response).to have_http_status(:success)
          expect(assigns(:can_set_default_assignments)).to be true
          expect(response.body).to include('Set 2 default assignments')
        end
      end

      context 'and viewer is neither in hierarchy nor has manage_employment' do
        let!(:peer_person) { create(:person) }
        let!(:peer_teammate) do
          ct = create(:company_teammate, person: peer_person, organization: organization, can_manage_employment: false)
          CompanyTeammate.find(ct.id)
        end

        before do
          create(:employment_tenure, teammate: peer_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
          peer_teammate.update!(first_employed_at: 1.year.ago)
          sign_in_as_teammate_for_request(peer_person, organization)
        end

        it 'shows disabled button with warning icon and tooltip' do
          get internal_organization_company_teammate_path(organization, employee_teammate)
          expect(response).to have_http_status(:success)
          expect(assigns(:required_assignments_without_active_tenure).size).to eq(2)
          expect(assigns(:can_set_default_assignments)).to be false
          expect(response.body).to include('Set 2 default assignments')
          expect(response.body).to include('disabled')
          expect(response.body).to include('bi-exclamation-triangle')
          # Tooltip text (apostrophe may be HTML-escaped as &#39;)
          expect(response.body).to include('managerial hierarchy or have the manage employment permission to set default assignments')
        end
      end
    end

    context 'when all required assignments have active tenure' do
      before do
        create(:assignment_tenure, teammate: employee_teammate, assignment: required_assignment1, started_at: 1.week.ago, ended_at: nil, anticipated_energy_percentage: 50)
        create(:assignment_tenure, teammate: employee_teammate, assignment: required_assignment2, started_at: 1.week.ago, ended_at: nil, anticipated_energy_percentage: 50)
        sign_in_as_teammate_for_request(manager_person, organization)
      end

      it 'does not show Set default assignments button' do
        get internal_organization_company_teammate_path(organization, employee_teammate)
        expect(response).to have_http_status(:success)
        expect(assigns(:required_assignments_without_active_tenure)).to be_empty
        expect(response.body).not_to include('Set ')
        expect(response.body).not_to include('default assignment')
      end
    end
  end

  describe 'POST set_default_assignments' do
    context 'when user is manager' do
      before { sign_in_as_teammate_for_request(manager_person, organization) }

      it 'creates assignment tenures for all missing required assignments' do
        expect {
          post set_default_assignments_organization_company_teammate_path(organization, employee_teammate)
        }.to change(AssignmentTenure, :count).by(2)

        expect(response).to redirect_to(internal_organization_company_teammate_path(organization, employee_teammate))
        expect(flash[:notice]).to include('Created 2 assignment tenure(s)')
        expect(flash[:notice]).to include('Assignment tenure check-in bypass')

        expect(AssignmentTenure.where(company_teammate: employee_teammate, assignment: required_assignment1).active.exists?).to be true
        expect(AssignmentTenure.where(company_teammate: employee_teammate, assignment: required_assignment2).active.exists?).to be true
      end

      it 'creates tenures with anticipated_energy_percentage 5%' do
        post set_default_assignments_organization_company_teammate_path(organization, employee_teammate)

        [required_assignment1, required_assignment2].each do |a|
          tenure = AssignmentTenure.find_by(company_teammate: employee_teammate, assignment: a)
          expect(tenure.anticipated_energy_percentage).to eq(5)
          expect(tenure.started_at).to eq(Date.current)
          expect(tenure.ended_at).to be_nil
        end
      end

      it 'creates one MAAP snapshot with reason Check-in Bypass' do
        expect {
          post set_default_assignments_organization_company_teammate_path(organization, employee_teammate)
        }.to change(MaapSnapshot, :count).by(1)

        snapshot = MaapSnapshot.last
        expect(snapshot.employee_company_teammate).to eq(employee_teammate)
        expect(snapshot.creator_company_teammate).to eq(manager_teammate)
        expect(snapshot.change_type).to eq('assignment_management')
        expect(snapshot.reason).to eq('Check-in Bypass')
      end
    end

    context 'when user has manage_employment but is not manager' do
      let!(:hr_person) { create(:person) }
      let!(:hr_teammate) do
        ct = create(:company_teammate, person: hr_person, organization: organization, can_manage_employment: true)
        CompanyTeammate.find(ct.id)
      end

      before do
        create(:employment_tenure, teammate: hr_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
        hr_teammate.update!(first_employed_at: 1.year.ago)
        sign_in_as_teammate_for_request(hr_person, organization)
      end

      it 'creates assignment tenures and MAAP snapshot' do
        expect {
          post set_default_assignments_organization_company_teammate_path(organization, employee_teammate)
        }.to change(AssignmentTenure, :count).by(2).and change(MaapSnapshot, :count).by(1)

        expect(response).to redirect_to(internal_organization_company_teammate_path(organization, employee_teammate))
        expect(MaapSnapshot.last.creator_company_teammate).to eq(hr_teammate)
      end
    end

    context 'when user does not have permission' do
      let!(:peer_person) { create(:person) }
      let!(:peer_teammate) do
        ct = create(:company_teammate, person: peer_person, organization: organization, can_manage_employment: false)
        CompanyTeammate.find(ct.id)
      end

      before do
        create(:employment_tenure, teammate: peer_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
        peer_teammate.update!(first_employed_at: 1.year.ago)
        sign_in_as_teammate_for_request(peer_person, organization)
      end

      it 'denies access and does not create tenures' do
        expect {
          post set_default_assignments_organization_company_teammate_path(organization, employee_teammate)
        }.not_to change(AssignmentTenure, :count)

        expect(response).to redirect_to(root_path)
      end
    end

    context 'when all required assignments already have active tenure' do
      before do
        create(:assignment_tenure, teammate: employee_teammate, assignment: required_assignment1, started_at: 1.week.ago, ended_at: nil)
        create(:assignment_tenure, teammate: employee_teammate, assignment: required_assignment2, started_at: 1.week.ago, ended_at: nil)
        sign_in_as_teammate_for_request(manager_person, organization)
      end

      it 'redirects with notice and does not create MAAP snapshot' do
        expect {
          post set_default_assignments_organization_company_teammate_path(organization, employee_teammate)
        }.not_to change(MaapSnapshot, :count)

        expect(response).to redirect_to(internal_organization_company_teammate_path(organization, employee_teammate))
        expect(flash[:notice]).to include('All required assignments already have active tenures')
      end
    end
  end
end
