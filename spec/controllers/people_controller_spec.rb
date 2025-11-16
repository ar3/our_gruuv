require 'rails_helper'

RSpec.describe PeopleController, type: :controller do
  let(:person) { create(:person, first_name: 'John', last_name: 'Doe', email: 'john@example.com') }

  before do
    # Create a teammate for the person - use default organization
    teammate = create(:teammate, person: person, organization: create(:organization, :company))
    sign_in_as_teammate(person, teammate.organization)
  end

  describe 'GET #show' do
    it 'returns http success' do
      get :show
      expect(response).to have_http_status(:success)
    end

    it 'assigns @person' do
      get :show
      expect(assigns(:person)).to eq(person)
    end

    context 'when not logged in' do
      before { session[:current_company_teammate_id] = nil }

      it 'redirects to root path' do
        get :show
        expect(response).to redirect_to(root_path)
      end
    end

    context 'authorization' do
      let(:organization) { create(:organization, :company) }
      let(:target_person) { create(:person) }
      let(:target_teammate) { create(:teammate, person: target_person, organization: organization) }
      let(:manager) { create(:person) }
      let(:manager_teammate) { create(:teammate, person: manager, organization: organization) }
      let(:employment_manager) { create(:person) }
      let(:employment_manager_teammate) { create(:teammate, person: employment_manager, organization: organization, can_manage_employment: true) }
      let(:regular_teammate_person) { create(:person) }
      let(:regular_teammate) { create(:teammate, person: regular_teammate_person, organization: organization) }

      before do
        # Create active employment for target person
        create(:employment_tenure, teammate: target_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
        # Create active employment for manager
        create(:employment_tenure, teammate: manager_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
        # Create active employment for employment manager
        create(:employment_tenure, teammate: employment_manager_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
        # Create active employment for regular teammate
        create(:employment_tenure, teammate: regular_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
        # Set manager relationship
        target_teammate.employment_tenures.first.update!(manager: manager)
      end

      context 'when user is the person themselves' do
        before do
          sign_in_as_teammate(target_person, organization)
        end

        it 'allows access' do
          get :show, params: { id: target_person.id }
          expect(response).to have_http_status(:success)
        end
      end

      context 'when user is the manager of the person' do
        before do
          sign_in_as_teammate(manager, organization)
        end

        it 'allows access' do
          get :show, params: { id: target_person.id }
          expect(response).to have_http_status(:success)
        end
      end

      context 'when user has employment management permissions' do
        before do
          sign_in_as_teammate(employment_manager, organization)
        end

        it 'allows access' do
          get :show, params: { id: target_person.id }
          expect(response).to have_http_status(:success)
        end
      end

      context 'when user is regular teammate (not manager, no permissions)' do
        before do
          sign_in_as_teammate(regular_teammate_person, organization)
        end

        it 'denies access' do
          get :show, params: { id: target_person.id }
          expect(response).to have_http_status(:redirect)
          expect(response).to redirect_to(public_person_path(target_person))
        end
      end

      context 'when user is from different organization' do
        let(:other_organization) { create(:organization, :company) }
        let(:other_org_person) { create(:person) }
        let(:other_org_teammate) { create(:teammate, person: other_org_person, organization: other_organization) }

        before do
          create(:employment_tenure, teammate: other_org_teammate, company: other_organization, started_at: 1.year.ago, ended_at: nil)
          sign_in_as_teammate(other_org_person, other_organization)
        end

        it 'denies access' do
          get :show, params: { id: target_person.id }
          expect(response).to have_http_status(:redirect)
          expect(response).to redirect_to(public_person_path(target_person))
        end
      end

      context 'when user is unauthenticated' do
        before do
          session[:current_company_teammate_id] = nil
        end

        it 'redirects to login' do
          get :show, params: { id: target_person.id }
          expect(response).to have_http_status(:redirect)
          expect(response).to redirect_to(root_path)
        end
      end
    end
  end

  describe 'PATCH #update' do
    context 'with valid parameters' do
      let(:valid_params) do
        {
          person: {
            first_name: 'Jane',
            last_name: 'Smith',
            timezone: 'Pacific Time (US & Canada)'
          }
        }
      end

      it 'updates the person' do
        patch :update, params: valid_params
        person.reload
        expect(person.first_name).to eq('Jane')
        expect(person.last_name).to eq('Smith')
        expect(person.timezone).to eq('Pacific Time (US & Canada)')
      end

      it 'redirects to profile path with notice' do
        patch :update, params: valid_params
        expect(response).to redirect_to(profile_path)
        expect(flash[:notice]).to eq('Profile updated successfully!')
      end
    end

    context 'with new fields' do
      let(:new_fields_params) do
        {
          person: {
            preferred_name: 'Johnny',
            gender_identity: 'man',
            pronouns: 'he/him'
          }
        }
      end

      it 'updates preferred_name' do
        patch :update, params: new_fields_params
        person.reload
        expect(person.preferred_name).to eq('Johnny')
      end

      it 'updates gender_identity' do
        patch :update, params: new_fields_params
        person.reload
        expect(person.gender_identity).to eq('man')
      end

      it 'updates pronouns' do
        patch :update, params: new_fields_params
        person.reload
        expect(person.pronouns).to eq('he/him')
      end
    end

    context 'with invalid parameters' do
      let(:invalid_params) do
        {
          person: {
            gender_identity: 'invalid_gender'
          }
        }
      end

      it 'does not update the person' do
        original_gender = person.gender_identity
        patch :update, params: invalid_params
        person.reload
        expect(person.gender_identity).to eq(original_gender)
      end

      it 'renders show template' do
        patch :update, params: invalid_params
        expect(response).to render_template(:show)
      end
    end

    context 'with blank phone number' do
      let(:blank_phone_params) do
        {
          person: {
            unique_textable_phone_number: ''
          }
        }
      end

      it 'successfully updates with blank phone number' do
        patch :update, params: blank_phone_params
        person.reload
        expect(person.unique_textable_phone_number).to be_nil
      end
    end

    context 'with duplicate phone number' do
      let!(:existing_person) { create(:person, unique_textable_phone_number: '+1234567890') }
      
      let(:duplicate_phone_params) do
        {
          person: {
            unique_textable_phone_number: '+1234567890'
          }
        }
      end

      it 'handles unique constraint violation gracefully' do
        patch :update, params: duplicate_phone_params
        expect(response).to render_template(:show)
        expect(assigns(:person).errors[:unique_textable_phone_number]).to include('has already been taken')
      end
    end

    context 'with database constraint violation' do
      before do
        allow_any_instance_of(Person).to receive(:update).and_raise(
          ActiveRecord::StatementInvalid.new('PG::UniqueViolation')
        )
      end

      it 'handles database constraint violation gracefully' do
        patch :update, params: { person: { first_name: 'Jane' } }
        expect(response).to render_template(:show)
        expect(assigns(:person).errors[:base]).to include('Unable to update profile due to a database constraint. Please try again.')
      end
    end

    context 'with unexpected error' do
      before do
        allow_any_instance_of(Person).to receive(:update).and_raise(StandardError.new('Unexpected error'))
      end

      it 'handles unexpected errors gracefully' do
        patch :update, params: { person: { first_name: 'Jane' } }
        expect(response).to render_template(:show)
        expect(assigns(:person).errors[:base]).to include('An unexpected error occurred while updating your profile. Please try again.')
      end
    end

    context 'when not logged in' do
      before { session[:current_company_teammate_id] = nil }

      it 'redirects to root path' do
        patch :update, params: { person: { first_name: 'Jane' } }
        expect(response).to redirect_to(root_path)
      end
    end

    context 'authorization' do
      let(:organization) { create(:organization, :company) }
      let(:target_person) { create(:person, first_name: 'Target', last_name: 'Person') }
      let(:target_teammate) { create(:teammate, person: target_person, organization: organization) }
      
      before do
        # Create active employment tenure for target person
        create(:employment_tenure, teammate: target_teammate, company: organization, ended_at: nil)
      end

      context 'when user is a manager with employment management permissions' do
        let(:manager) { create(:person) }
        let(:manager_teammate) { create(:teammate, person: manager, organization: organization, can_manage_employment: true) }
        
        before do
          create(:employment_tenure, teammate: manager_teammate, company: organization, ended_at: nil)
          sign_in_as_teammate(manager, organization)
        end

        it 'allows updating the target person via person_path' do
          patch :update, params: { id: target_person.id, person: { first_name: 'Updated' } }
          target_person.reload
          expect(target_person.first_name).to eq('Updated')
        end

        it 'redirects to profile path with notice' do
          patch :update, params: { id: target_person.id, person: { first_name: 'Updated' } }
          expect(response).to redirect_to(profile_path)
          expect(flash[:notice]).to eq('Profile updated successfully!')
        end
      end

      context 'when user is in managerial hierarchy' do
        let(:manager) { create(:person) }
        let(:manager_teammate) { create(:teammate, person: manager, organization: organization) }
        
        before do
          # Create active employment tenure for manager
          create(:employment_tenure, teammate: manager_teammate, company: organization, ended_at: nil)
          # Set manager as the manager of target person's active employment tenure
          target_employment = target_person.employment_tenures.find_by(company: organization)
          target_employment.update!(manager: manager, ended_at: nil)
          sign_in_as_teammate(manager, organization)
        end

        it 'allows updating the target person via person_path' do
          patch :update, params: { id: target_person.id, person: { first_name: 'Updated' } }
          target_person.reload
          expect(target_person.first_name).to eq('Updated')
        end
      end

      # Note: Authorization is tested in spec/policies/person_policy_spec.rb
      # The controller test focuses on the update functionality when authorized
    end
  end

  describe 'GET #public' do
    let(:organization) { create(:organization, :company) }
    let(:other_organization) { create(:organization, :company) }
    let(:teammate) { create(:teammate, person: person, organization: organization) }
    let(:other_teammate) { create(:teammate, person: person, organization: other_organization) }
    
    let!(:public_observation) do
      observer = create(:person)
      obs = create(:observation, 
        observer: observer, 
        company: organization,
        privacy_level: 'public_observation',
        published_at: 1.day.ago,
        observed_at: 1.day.ago
      )
      create(:observee, observation: obs, teammate: teammate)
      obs
    end
    
    let!(:private_observation) do
      observer = create(:person)
      obs = create(:observation,
        observer: observer,
        company: organization,
        privacy_level: 'observer_only',
        published_at: 1.day.ago,
        observed_at: 1.day.ago
      )
      create(:observee, observation: obs, teammate: teammate)
      obs
    end
    
    let!(:unpublished_observation) do
      observer = create(:person)
      obs = create(:observation,
        observer: observer,
        company: organization,
        privacy_level: 'public_observation',
        published_at: nil,
        observed_at: 1.day.ago
      )
      create(:observee, observation: obs, teammate: teammate)
      obs
    end
    
    let!(:milestone) do
      ability = create(:ability, organization: organization)
      create(:teammate_milestone, 
        teammate: teammate, 
        ability: ability,
        milestone_level: 3,
        attained_at: 1.month.ago
      )
    end
    
    let!(:other_milestone) do
      ability = create(:ability, organization: other_organization)
      create(:teammate_milestone,
        teammate: other_teammate,
        ability: ability,
        milestone_level: 2,
        attained_at: 2.months.ago
      )
    end

    it 'returns http success without authentication' do
      session[:current_company_teammate_id] = nil
      get :public, params: { id: person.id }
      expect(response).to have_http_status(:success)
    end

    it 'uses unauthenticated layout' do
      get :public, params: { id: person.id }
      expect(response).to render_template(layout: 'application')
    end

    it 'assigns @person' do
      get :public, params: { id: person.id }
      expect(assigns(:person)).to eq(person)
    end

    it 'loads only public published observations where person is observed' do
      get :public, params: { id: person.id }
      observations = assigns(:public_observations)
      observation_ids = observations.map(&:id)
      expect(observation_ids).to include(public_observation.id)
      expect(observation_ids).not_to include(private_observation.id)
      expect(observation_ids).not_to include(unpublished_observation.id)
    end

    it 'loads milestones from all organizations' do
      get :public, params: { id: person.id }
      milestones = assigns(:milestones)
      milestone_ids = milestones.map(&:id)
      expect(milestone_ids).to include(milestone.id)
      expect(milestone_ids).to include(other_milestone.id)
    end

    it 'orders observations by observed_at desc' do
      older_obs = create(:observation,
        observer: create(:person),
        company: organization,
        privacy_level: 'public_observation',
        published_at: 2.days.ago,
        observed_at: 2.days.ago
      )
      create(:observee, observation: older_obs, teammate: teammate)
      
      get :public, params: { id: person.id }
      observations = assigns(:public_observations)
      expect(observations.first.id).to eq(public_observation.id)
      expect(observations.second.id).to eq(older_obs.id)
    end

    it 'orders milestones by attained_at desc' do
      get :public, params: { id: person.id }
      milestones = assigns(:milestones)
      expect(milestones.first.id).to eq(milestone.id)
      expect(milestones.second.id).to eq(other_milestone.id)
    end

    it 'decorates observations' do
      get :public, params: { id: person.id }
      observations = assigns(:public_observations)
      expect(observations.first).to respond_to(:permalink_path)
    end
  end
end 