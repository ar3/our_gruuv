require 'rails_helper'

RSpec.describe PeopleController, type: :controller do
  let(:person) { create(:person, first_name: 'John', last_name: 'Doe', email: 'john@example.com') }

  before do
    # Create a teammate for the person - use default organization
    teammate = create(:teammate, person: person, organization: create(:organization, :company))
    sign_in_as_teammate(person, teammate.organization)
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
        privacy_level: 'public_to_world',
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
        privacy_level: 'public_to_world',
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
        attained_at: 1.month.ago,
        public_profile_published_at: 1.week.ago
      )
    end
    
    let!(:other_milestone) do
      ability = create(:ability, organization: other_organization)
      create(:teammate_milestone,
        teammate: other_teammate,
        ability: ability,
        milestone_level: 2,
        attained_at: 2.months.ago,
        public_profile_published_at: 1.week.ago
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

    it 'only loads milestones with public_profile_published_at' do
      # Create a milestone without public_profile_published_at
      ability = create(:ability, organization: organization)
      unpublished_milestone = create(:teammate_milestone,
        teammate: teammate,
        ability: ability,
        milestone_level: 1,
        attained_at: 3.months.ago,
        public_profile_published_at: nil
      )
      
      get :public, params: { id: person.id }
      milestones = assigns(:milestones)
      milestone_ids = milestones.map(&:id)
      expect(milestone_ids).to include(milestone.id)
      expect(milestone_ids).to include(other_milestone.id)
      expect(milestone_ids).not_to include(unpublished_milestone.id)
    end

    it 'orders observations by observed_at desc' do
      older_obs = create(:observation,
        observer: create(:person),
        company: organization,
        privacy_level: 'public_to_world',
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