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
  end

  describe 'GET #edit' do
    it 'returns http success' do
      get :edit
      expect(response).to have_http_status(:success)
    end

    it 'assigns @person' do
      get :edit
      expect(assigns(:person)).to eq(person)
    end

    context 'when not logged in' do
      before { session[:current_company_teammate_id] = nil }

      it 'redirects to root path' do
        get :edit
        expect(response).to redirect_to(root_path)
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

    context 'with invalid parameters' do
      let(:invalid_params) do
        {
          person: {
            email: 'invalid-email'
          }
        }
      end

      it 'does not update the person' do
        original_email = person.email
        patch :update, params: invalid_params
        person.reload
        expect(person.email).to eq(original_email)
      end

      it 'renders edit template' do
        patch :update, params: invalid_params
        expect(response).to render_template(:edit)
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
        expect(response).to render_template(:edit)
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
        expect(response).to render_template(:edit)
        expect(assigns(:person).errors[:base]).to include('Unable to update profile due to a database constraint. Please try again.')
      end
    end

    context 'with unexpected error' do
      before do
        allow_any_instance_of(Person).to receive(:update).and_raise(StandardError.new('Unexpected error'))
      end

      it 'handles unexpected errors gracefully' do
        patch :update, params: { person: { first_name: 'Jane' } }
        expect(response).to render_template(:edit)
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