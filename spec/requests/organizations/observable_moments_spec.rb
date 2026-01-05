require 'rails_helper'

RSpec.describe 'Organizations::ObservableMoments', type: :request do
  let(:company) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, person: person, organization: company) }
  let(:other_person) { create(:person, email: "other#{SecureRandom.hex(4)}@example.com") }
  let(:other_teammate) { create(:teammate, person: other_person, organization: company) }
  let(:observable_moment) do
    create(:observable_moment, :new_hire, company: company, primary_observer_person: person)
  end

  before do
    teammate # Ensure teammate is created
    sign_in_as_teammate_for_request(person, company)
    PaperTrail.enabled = false
  end

  after do
    PaperTrail.enabled = true
  end

  describe 'POST /organizations/:organization_id/observable_moments/:id/create_observation' do
    it 'redirects to observation creation with observable_moment_id' do
      post "/organizations/#{company.id}/observable_moments/#{observable_moment.id}/create_observation"
      
      expect(response).to redirect_to(new_organization_observation_path(company, observable_moment_id: observable_moment.id))
    end

    it 'requires user to be the primary potential observer' do
      sign_in_as_teammate_for_request(other_person, company)
      
      post "/organizations/#{company.id}/observable_moments/#{observable_moment.id}/create_observation"
      
      expect(response).to redirect_to("/organizations/#{company.to_param}/get_shit_done")
      expect(flash[:alert]).to be_present
    end
  end

  describe 'GET /organizations/:organization_id/observable_moments/:id/reassign' do
    it 'renders the reassign page' do
      # Ensure teammates are CompanyTeammates
      company_teammate = CompanyTeammate.find_or_create_by!(person: person, organization: company)
      other_company_teammate = CompanyTeammate.find_or_create_by!(person: other_person, organization: company)
      
      get "/organizations/#{company.id}/observable_moments/#{observable_moment.id}/reassign"
      
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Reassign Observable Moment')
      expect(response.body).to include(company_teammate.person.display_name)
      expect(response.body).to include(other_company_teammate.person.display_name)
    end

    it 'requires user to be the primary potential observer' do
      sign_in_as_teammate_for_request(other_person, company)
      
      get "/organizations/#{company.id}/observable_moments/#{observable_moment.id}/reassign"
      
      expect(response).to redirect_to("/organizations/#{company.to_param}/get_shit_done")
    end
  end

  describe 'PATCH /organizations/:organization_id/observable_moments/:id/reassign' do
    it 'reassigns the moment to a new teammate' do
      # Ensure other_teammate is a CompanyTeammate
      other_company_teammate = CompanyTeammate.find_or_create_by!(person: other_person, organization: company)
      patch "/organizations/#{company.id}/observable_moments/#{observable_moment.id}/reassign",
            params: { teammate_id: other_company_teammate.id }
      
      expect(response).to redirect_to("/organizations/#{company.to_param}/get_shit_done")
      expect(flash[:notice]).to include('reassigned successfully')
      expect(observable_moment.reload.primary_potential_observer).to eq(other_company_teammate)
    end

    it 'rejects invalid teammate_id' do
      patch "/organizations/#{company.to_param}/observable_moments/#{observable_moment.id}/reassign",
            params: { teammate_id: 99999 }
      
      expect(response).to redirect_to("/organizations/#{company.to_param}/observable_moments/#{observable_moment.id}/reassign")
      expect(flash[:alert]).to include('Invalid teammate')
    end

    it 'requires user to be the primary potential observer' do
      sign_in_as_teammate_for_request(other_person, company)
      
      # Ensure teammate is a CompanyTeammate for comparison
      company_teammate = CompanyTeammate.find_or_create_by!(person: person, organization: company)
      other_company_teammate = CompanyTeammate.find_or_create_by!(person: other_person, organization: company)
      
      patch "/organizations/#{company.to_param}/observable_moments/#{observable_moment.id}/reassign",
            params: { teammate_id: other_company_teammate.id }
      
      expect(response).to redirect_to("/organizations/#{company.to_param}/get_shit_done")
      expect(observable_moment.reload.primary_potential_observer).to eq(company_teammate)
    end
  end

  describe 'PATCH /organizations/:organization_id/observable_moments/:id/ignore' do
    it 'marks the moment as processed without creating observation' do
      expect(observable_moment.processed?).to be false
      
      # Ensure teammate is a CompanyTeammate for comparison
      company_teammate = CompanyTeammate.find_or_create_by!(person: person, organization: company)
      
      patch "/organizations/#{company.id}/observable_moments/#{observable_moment.id}/ignore"
      
      expect(response).to redirect_to("/organizations/#{company.to_param}/get_shit_done")
      expect(flash[:notice]).to include('ignored')
      expect(observable_moment.reload.processed?).to be true
      expect(observable_moment.processed_by_teammate).to eq(company_teammate)
      expect(observable_moment.observations.count).to eq(0)
    end

    it 'requires user to be the primary potential observer' do
      sign_in_as_teammate_for_request(other_person, company)
      
      patch "/organizations/#{company.id}/observable_moments/#{observable_moment.id}/ignore"
      
      expect(response).to redirect_to("/organizations/#{company.to_param}/get_shit_done")
      expect(observable_moment.reload.processed?).to be false
    end
  end
end

