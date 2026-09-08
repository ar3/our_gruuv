# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Organizations::CompanyTeammates::EmploymentHistoryCorrections', type: :request do
  let(:organization) { create(:organization, :company) }
  let(:employee) { create(:person, first_name: 'Sam', preferred_name: 'Sammy') }
  let(:employee_teammate) do
    create(:company_teammate, person: employee, organization: organization, first_employed_at: 1.year.ago)
  end
  let(:manager_person) { create(:person) }
  let(:manager_teammate) do
    create(
      :company_teammate,
      person: manager_person,
      organization: organization,
      can_manage_employment: true,
      first_employed_at: 2.years.ago
    )
  end
  let(:position) do
    pml = create(:position_major_level)
    title = create(:title, company: organization, position_major_level: pml)
    level = create(:position_level, position_major_level: pml)
    create(:position, title: title, position_level: level)
  end
  let!(:employment_tenure) do
    create(
      :employment_tenure,
      teammate: employee_teammate,
      company: organization,
      position: position,
      started_at: 1.year.ago,
      ended_at: nil
    )
  end

  before do
    create(
      :employment_tenure,
      teammate: manager_teammate,
      company: organization,
      started_at: 2.years.ago,
      ended_at: nil
    )
  end

  describe 'GET show' do
    context 'with manage_employment' do
      before { sign_in_as_teammate_for_request(manager_person, organization) }

      it 'renders the correct history page with enabled save actions' do
        get organization_company_teammate_employment_history_correction_path(organization, employee_teammate)

        expect(response).to have_http_status(:success)
        expect(response.body).to include('Correct Employment History')
        expect(response.body).to include('Derived from current tenures')
        expect(response.body).to include('Prepend earliest tenure')
        expect(response.body).to include('Total employed')
        expect(response.body).to include(page_help_id_hint)
        expect(response.body).to include('Save tenure')
        expect(response.body).not_to include('You need employment management permission to correct employment history.')
      end
    end

    context 'as a manager in hierarchy without manage_employment' do
      let(:line_manager) { create(:person) }
      let!(:line_manager_teammate) do
        create(
          :company_teammate,
          person: line_manager,
          organization: organization,
          can_manage_employment: false,
          first_employed_at: 2.years.ago
        )
      end

      before do
        create(:employment_tenure, teammate: line_manager_teammate, company: organization, started_at: 2.years.ago, ended_at: nil)
        employment_tenure.update!(manager_teammate: line_manager_teammate)
        sign_in_as_teammate_for_request(line_manager, organization)
      end

      it 'allows viewing with disabled save actions and explanation tooltip' do
        get organization_company_teammate_employment_history_correction_path(organization, employee_teammate)

        expect(response).to have_http_status(:success)
        expect(response.body).to include('Correct Employment History')
        expect(response.body).to include('You need employment management permission to correct employment history.')
        expect(response.body).to include('disabled')
      end

      it 'denies mutating updates' do
        patch tenure_organization_company_teammate_employment_history_correction_path(organization, employee_teammate, employment_tenure),
              params: {
                employment_tenure: {
                  position_id: position.id,
                  started_at: 18.months.ago.to_date,
                  ended_at: ''
                }
              }

        expect(response).to have_http_status(:redirect).or have_http_status(:forbidden)
        expect(employment_tenure.reload.started_at.to_date).to eq(1.year.ago.to_date)
      end
    end

    context 'as a peer outside hierarchy' do
      let(:peer) { create(:person) }
      let!(:peer_teammate) do
        create(:company_teammate, person: peer, organization: organization, can_manage_employment: false, first_employed_at: 1.year.ago)
      end

      before do
        create(:employment_tenure, teammate: peer_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
        sign_in_as_teammate_for_request(peer, organization)
      end

      it 'denies access' do
        get organization_company_teammate_employment_history_correction_path(organization, employee_teammate)
        expect(response).to have_http_status(:redirect).or have_http_status(:forbidden)
      end
    end
  end

  describe 'PATCH update_tenure' do
    before { sign_in_as_teammate_for_request(manager_person, organization) }

    it 'updates the tenure and redirects' do
      patch tenure_organization_company_teammate_employment_history_correction_path(organization, employee_teammate, employment_tenure),
            params: {
              employment_tenure: {
                position_id: position.id,
                started_at: 18.months.ago.to_date,
                ended_at: ''
              }
            }

      expect(response).to redirect_to(organization_company_teammate_employment_history_correction_path(organization, employee_teammate))
      expect(employment_tenure.reload.started_at.to_date).to eq(18.months.ago.to_date)
      expect(employee_teammate.reload.first_employed_at).to eq(18.months.ago.to_date)
    end
  end

  describe 'POST prepend' do
    before { sign_in_as_teammate_for_request(manager_person, organization) }

    it 'prepends an earliest tenure' do
      expect {
        post prepend_organization_company_teammate_employment_history_correction_path(organization, employee_teammate),
             params: {
               employment_tenure: {
                 position_id: position.id,
                 started_at: 3.years.ago.to_date,
                 ended_at: 1.year.ago.to_date
               }
             }
      }.to change { employee_teammate.employment_tenures.count }.by(1)

      expect(response).to redirect_to(organization_company_teammate_employment_history_correction_path(organization, employee_teammate))
      expect(employee_teammate.reload.first_employed_at).to eq(3.years.ago.to_date)
    end
  end

  def page_help_id_hint
    'employmentHistoryCorrectionPageHelp'
  end
end
