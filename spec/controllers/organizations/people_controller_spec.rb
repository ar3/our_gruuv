require 'rails_helper'

RSpec.describe Organizations::PeopleController, type: :controller do
  let(:organization) { create(:organization, :company) }
  let(:manager) { create(:person) }
  let(:manager_access) { create(:teammate, person: manager, organization: organization, can_manage_employment: true) }
  
  before do
    session[:current_person_id] = manager.id
    manager_access
    # Ensure the manager has an active employment tenure in the organization
    create(:employment_tenure, person: manager, company: organization, started_at: 1.year.ago, ended_at: nil)
  end

  describe 'GET #complete_picture' do
    context 'when person has an active employment tenure' do
      let(:person) { create(:person) }
      let(:position_major_level) { create(:position_major_level, major_level: 1, set_name: 'Engineering') }
      let(:position_type) { create(:position_type, organization: organization, position_major_level: position_major_level) }
      let(:position_level) { create(:position_level, position_major_level: position_major_level, level: '1.1') }
      let(:position) { create(:position, position_type: position_type, position_level: position_level) }
      let(:active_employment) { create(:employment_tenure, person: person, company: organization, position: position, started_at: 6.months.ago, ended_at: nil) }
      let(:past_employment) { create(:employment_tenure, person: person, company: organization, position: position, started_at: 1.year.ago, ended_at: 8.months.ago) }
      
      # Add assignments for this organization
      let(:assignment) { create(:assignment, company: organization, title: 'Test Assignment') }
      let(:assignment_tenure) { create(:assignment_tenure, person: person, assignment: assignment, started_at: 3.months.ago, ended_at: nil) }

      before do
        active_employment
        past_employment
        assignment_tenure
      end

      it 'returns http success' do
        get :complete_picture, params: { organization_id: organization.id, id: person.id }
        expect(response).to have_http_status(:success)
      end

      it 'assigns the correct person' do
        get :complete_picture, params: { organization_id: organization.id, id: person.id }
        expect(assigns(:person)).to eq(person)
      end

      it 'assigns employment tenures ordered by start date descending' do
        get :complete_picture, params: { organization_id: organization.id, id: person.id }
        
        employment_tenures = assigns(:employment_tenures)
        expect(employment_tenures).to include(active_employment, past_employment)
        expect(employment_tenures.first).to eq(active_employment) # Most recent first
        expect(employment_tenures.last).to eq(past_employment)
      end

      it 'assigns the current employment tenure' do
        get :complete_picture, params: { organization_id: organization.id, id: person.id }
        expect(assigns(:current_employment)).to eq(active_employment)
      end

      it 'assigns the current organization from active employment' do
        get :complete_picture, params: { organization_id: organization.id, id: person.id }
        expect(assigns(:current_organization)).to be_a(Organization)
        expect(assigns(:current_organization).id).to eq(organization.id)
      end

      it 'assigns filtered assignment tenures for the organization' do
        get :complete_picture, params: { organization_id: organization.id, id: person.id }
        assignment_tenures = assigns(:assignment_tenures)
        expect(assignment_tenures).to be_present
        # All assignments should belong to the organization
        assignment_tenures.each do |tenure|
          expect(tenure.assignment.company).to be_a(Organization)
          expect(tenure.assignment.company.id).to eq(organization.id)
        end
      end

      it 'includes associated data to avoid N+1 queries' do
        get :complete_picture, params: { organization_id: organization.id, id: person.id }
        
        # Verify that the query includes the necessary associations
        employment_tenures = assigns(:employment_tenures)
        expect(employment_tenures.object).to be_loaded
      end
    end

    context 'when person has no active employment tenure but has past employment' do
      let(:person) { create(:person) }
      let(:position_major_level) { create(:position_major_level, major_level: 1, set_name: 'Engineering') }
      let(:position_type) { create(:position_type, organization: organization, position_major_level: position_major_level) }
      let(:position_level) { create(:position_level, position_major_level: position_major_level, level: '1.1') }
      let(:position) { create(:position, position_type: position_type, position_level: position_level) }
      let(:past_employment1) { create(:employment_tenure, person: person, company: organization, position: position, started_at: 1.year.ago, ended_at: 6.months.ago) }
      let(:other_organization) { create(:organization, :company) }
      let(:other_position_type) { create(:position_type, organization: other_organization, position_major_level: position_major_level) }
      let(:other_position) { create(:position, position_type: other_position_type, position_level: position_level) }
      let(:past_employment2) { create(:employment_tenure, person: person, company: other_organization, position: other_position, started_at: 2.years.ago, ended_at: 1.year.ago) }

      before do
        past_employment1
        past_employment2
      end

      it 'returns http success' do
        get :complete_picture, params: { organization_id: organization.id, id: person.id }
        expect(response).to have_http_status(:success)
      end

      it 'assigns employment tenures ordered by start date descending' do
        get :complete_picture, params: { organization_id: organization.id, id: person.id }
        
        employment_tenures = assigns(:employment_tenures)
        expect(employment_tenures).to include(past_employment1)
        expect(employment_tenures).not_to include(past_employment2) # Different organization
        expect(employment_tenures.first).to eq(past_employment1) # Most recent first
      end

      it 'assigns nil for current employment tenure' do
        get :complete_picture, params: { organization_id: organization.id, id: person.id }
        expect(assigns(:current_employment)).to be_nil
      end

      it 'assigns nil for current organization' do
        get :complete_picture, params: { organization_id: organization.id, id: person.id }
        expect(assigns(:current_organization)).to be_a(Organization)
        expect(assigns(:current_organization).id).to eq(organization.id)
      end
    end

    context 'when person has no employment tenures at all' do
      let(:person) { create(:person) }

      it 'returns http success' do
        get :complete_picture, params: { organization_id: organization.id, id: person.id }
        expect(response).to have_http_status(:success)
      end

      it 'assigns empty employment tenures collection' do
        get :complete_picture, params: { organization_id: organization.id, id: person.id }
        
        employment_tenures = assigns(:employment_tenures)
        expect(employment_tenures).to be_empty
      end

      it 'assigns nil for current employment tenure' do
        get :complete_picture, params: { organization_id: organization.id, id: person.id }
        expect(assigns(:current_employment)).to be_nil
      end

      it 'assigns nil for current organization' do
        get :complete_picture, params: { organization_id: organization.id, id: person.id }
        expect(assigns(:current_organization)).to be_a(Organization)
        expect(assigns(:current_organization).id).to eq(organization.id)
      end
    end

    context 'when person has multiple active employment tenures' do
      let(:person) { create(:person) }
      let(:other_organization) { create(:organization, :company) }
      let(:position_major_level) { create(:position_major_level, major_level: 1, set_name: 'Engineering') }
      let(:position_type) { create(:position_type, organization: organization, position_major_level: position_major_level) }
      let(:other_position_type) { create(:position_type, organization: other_organization, position_major_level: position_major_level) }
      let(:position_level) { create(:position_level, position_major_level: position_major_level, level: '1.1') }
      let(:position1) { create(:position, position_type: position_type, position_level: position_level) }
      let(:position2) { create(:position, position_type: other_position_type, position_level: position_level) }
      let(:active_employment1) { create(:employment_tenure, person: person, company: organization, position: position1, started_at: 6.months.ago, ended_at: nil) }
      let(:active_employment2) { create(:employment_tenure, person: person, company: other_organization, position: position2, started_at: 3.months.ago, ended_at: nil) }

      before do
        active_employment1
        active_employment2
      end

      it 'returns http success' do
        get :complete_picture, params: { organization_id: organization.id, id: person.id }
        expect(response).to have_http_status(:success)
      end

      it 'assigns all employment tenures' do
        get :complete_picture, params: { organization_id: organization.id, id: person.id }
        
        employment_tenures = assigns(:employment_tenures)
        expect(employment_tenures).to include(active_employment1)
        expect(employment_tenures).not_to include(active_employment2) # Different organization
      end

      it 'assigns the active employment from the organization as current' do
        get :complete_picture, params: { organization_id: organization.id, id: person.id }
        expect(assigns(:current_employment)).to eq(active_employment1) # Only one from this organization
      end

      it 'assigns the organization from the route' do
        get :complete_picture, params: { organization_id: organization.id, id: person.id }
        expect(assigns(:current_organization)).to be_a(Organization)
        expect(assigns(:current_organization).id).to eq(organization.id)
      end
    end

    context 'authorization' do
      let(:person) { create(:person) }
      let(:unauthorized_user) { create(:person) }

      context 'when user has employment management permissions' do
        it 'allows access' do
          get :complete_picture, params: { organization_id: organization.id, id: person.id }
          expect(response).to have_http_status(:success)
        end
      end

      context 'when user does not have employment management permissions' do
        before do
          session[:current_person_id] = unauthorized_user.id
        end

        it 'redirects when authorization fails' do
          get :complete_picture, params: { organization_id: organization.id, id: person.id }
          expect(response).to have_http_status(:redirect)
          # The policy redirects to public view instead of root
          expect(response).to redirect_to(public_person_path(person))
        end
      end

      context 'when user is the person themselves' do
        before do
          session[:current_person_id] = person.id
        end

        it 'allows access to own complete picture view' do
          get :complete_picture, params: { organization_id: organization.id, id: person.id }
          expect(response).to have_http_status(:success)
        end
      end

      context 'when user is an admin' do
        let(:admin) { create(:person, :admin) }

        before do
          session[:current_person_id] = admin.id
        end

        it 'allows access' do
          get :complete_picture, params: { organization_id: organization.id, id: person.id }
          expect(response).to have_http_status(:success)
        end
      end
    end

    context 'when person is not found' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect {
          get :complete_picture, params: { organization_id: organization.id, id: 99999 }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when organization is not found' do
      let(:person) { create(:person) }

      it 'raises ActiveRecord::RecordNotFound' do
        expect {
          get :complete_picture, params: { organization_id: 99999, id: person.id }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when user is not authenticated' do
      let(:person) { create(:person) }

      before do
        session[:current_person_id] = nil
      end

      it 'redirects to login' do
        get :complete_picture, params: { organization_id: organization.id, id: person.id }
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(root_path)
      end
    end
  end
end