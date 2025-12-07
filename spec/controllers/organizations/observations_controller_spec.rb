require 'rails_helper'

RSpec.describe Organizations::ObservationsController, type: :controller do
  render_views
  
  let(:company) { create(:organization, :company) }
  let(:observer) { create(:person) }
  let(:observer_teammate) { create(:teammate, person: observer, organization: company) }
  let(:observee_person) { create(:person) }
  let(:observee_teammate) { create(:teammate, person: observee_person, organization: company) }
  let(:observation) do
    obs = build(:observation, observer: observer, company: company)
    obs.observees.build(teammate: observee_teammate)
    obs.save!
    obs
  end

  before do
    sign_in_as_teammate(observer, company)
  end

  describe 'GET #index' do
    it 'renders the index page' do
      get :index, params: { organization_id: company.id }
      expect(response).to have_http_status(:success)
    end

    it 'assigns observations' do
      observation # Create the observation
      get :index, params: { organization_id: company.id }
      expect(assigns(:observations)).to include(observation)
    end

    it 'calculates spotlight stats with feedback_health spotlight' do
      get :index, params: { organization_id: company.id, spotlight: 'feedback_health' }
      expect(response).to have_http_status(:success)
      expect(assigns(:spotlight_stats)).to be_a(Hash)
      expect(assigns(:spotlight_stats)).to have_key(:matrix)
      expect(assigns(:spotlight_stats)).to have_key(:given_stats)
      expect(assigns(:spotlight_stats)).to have_key(:received_stats)
    end

    it 'renders feedback_health spotlight partial when spotlight is feedback_health' do
      get :index, params: { organization_id: company.id, spotlight: 'feedback_health' }
      expect(response).to have_http_status(:success)
      expect(response.body).to include('This spotlight looks at all observations throughout the entire company')
    end
  end

  describe 'GET #show' do
    let(:manager_person) { create(:person) }
    let(:manager_teammate) { create(:teammate, person: manager_person, organization: company) }
    let(:random_person) { create(:person) }
    let(:random_teammate) { create(:teammate, person: random_person, organization: company) }

    before do
      # Set up managerial hierarchy: observee -> manager
      create(:employment_tenure, teammate: manager_teammate, company: company)
      create(:employment_tenure, teammate: observee_teammate, company: company, manager: manager_person)
    end

    context 'observer_only privacy' do
      let(:observer_only_observation) do
        obs = build(:observation, observer: observer, company: company, privacy_level: :observer_only)
        obs.observees.build(teammate: observee_teammate)
        obs.save!
        obs.publish!
        obs
      end

      it 'allows observer to view' do
        get :show, params: { organization_id: company.id, id: observer_only_observation.id }
        expect(response).to have_http_status(:success)
      end

      it 'redirects observee to kudos page' do
        sign_in_as_teammate(observee_person, company)
        get :show, params: { organization_id: company.id, id: observer_only_observation.id }
        date_part = observer_only_observation.observed_at.strftime('%Y-%m-%d')
        expect(response).to redirect_to(organization_kudo_path(company, date: date_part, id: observer_only_observation.id))
      end

      it 'redirects manager to kudos page' do
        sign_in_as_teammate(manager_person, company)
        get :show, params: { organization_id: company.id, id: observer_only_observation.id }
        date_part = observer_only_observation.observed_at.strftime('%Y-%m-%d')
        expect(response).to redirect_to(organization_kudo_path(company, date: date_part, id: observer_only_observation.id))
      end

      it 'redirects random person to kudos page' do
        sign_in_as_teammate(random_person, company)
        get :show, params: { organization_id: company.id, id: observer_only_observation.id }
        date_part = observer_only_observation.observed_at.strftime('%Y-%m-%d')
        expect(response).to redirect_to(organization_kudo_path(company, date: date_part, id: observer_only_observation.id))
      end
    end

    context 'observed_only privacy' do
      it 'allows observer to view' do
        get :show, params: { organization_id: company.id, id: observation.id }
        expect(response).to have_http_status(:success)
      end

      it 'allows observee to view' do
        sign_in_as_teammate(observee_person, company)
        get :show, params: { organization_id: company.id, id: observation.id }
        expect(response).to have_http_status(:success)
      end

      it 'redirects manager to kudos page' do
        sign_in_as_teammate(manager_person, company)
        get :show, params: { organization_id: company.id, id: observation.id }
        date_part = observation.observed_at.strftime('%Y-%m-%d')
        expect(response).to redirect_to(organization_kudo_path(company, date: date_part, id: observation.id))
      end

      it 'redirects random person to kudos page' do
        sign_in_as_teammate(random_person, company)
        get :show, params: { organization_id: company.id, id: observation.id }
        date_part = observation.observed_at.strftime('%Y-%m-%d')
        expect(response).to redirect_to(organization_kudo_path(company, date: date_part, id: observation.id))
      end
    end

    context 'managers_only privacy' do
      let(:managers_only_observation) do
        obs = build(:observation, observer: observer, company: company, privacy_level: :managers_only)
        obs.observees.build(teammate: observee_teammate)
        obs.save!
        obs.publish!
        obs
      end

      it 'allows observer to view' do
        get :show, params: { organization_id: company.id, id: managers_only_observation.id }
        expect(response).to have_http_status(:success)
      end

      it 'allows manager to view' do
        sign_in_as_teammate(manager_person, company)
        get :show, params: { organization_id: company.id, id: managers_only_observation.id }
        expect(response).to have_http_status(:success)
      end

      it 'redirects observee to kudos page' do
        sign_in_as_teammate(observee_person, company)
        get :show, params: { organization_id: company.id, id: managers_only_observation.id }
        date_part = managers_only_observation.observed_at.strftime('%Y-%m-%d')
        expect(response).to redirect_to(organization_kudo_path(company, date: date_part, id: managers_only_observation.id))
      end

      it 'redirects random person to kudos page' do
        sign_in_as_teammate(random_person, company)
        get :show, params: { organization_id: company.id, id: managers_only_observation.id }
        date_part = managers_only_observation.observed_at.strftime('%Y-%m-%d')
        expect(response).to redirect_to(organization_kudo_path(company, date: date_part, id: managers_only_observation.id))
      end
    end

    context 'observed_and_managers privacy' do
      let(:observed_and_managers_observation) do
        obs = build(:observation, observer: observer, company: company, privacy_level: :observed_and_managers)
        obs.observees.build(teammate: observee_teammate)
        obs.save!
        obs.publish!
        obs
      end

      it 'allows observer to view' do
        get :show, params: { organization_id: company.id, id: observed_and_managers_observation.id }
        expect(response).to have_http_status(:success)
      end

      it 'allows observee to view' do
        sign_in_as_teammate(observee_person, company)
        get :show, params: { organization_id: company.id, id: observed_and_managers_observation.id }
        expect(response).to have_http_status(:success)
      end

      it 'allows manager to view' do
        sign_in_as_teammate(manager_person, company)
        get :show, params: { organization_id: company.id, id: observed_and_managers_observation.id }
        expect(response).to have_http_status(:success)
      end

      it 'redirects random person to kudos page' do
        sign_in_as_teammate(random_person, company)
        get :show, params: { organization_id: company.id, id: observed_and_managers_observation.id }
        date_part = observed_and_managers_observation.observed_at.strftime('%Y-%m-%d')
        expect(response).to redirect_to(organization_kudo_path(company, date: date_part, id: observed_and_managers_observation.id))
      end
    end

    context 'public_to_company privacy' do
      let(:public_company_observation) do
        obs = build(:observation, observer: observer, company: company, privacy_level: :public_to_company)
        obs.observees.build(teammate: observee_teammate)
        obs.save!
        obs.publish!
        obs
      end

      it 'allows observer to view' do
        get :show, params: { organization_id: company.id, id: public_company_observation.id }
        expect(response).to have_http_status(:success)
      end

      it 'allows observee to view' do
        sign_in_as_teammate(observee_person, company)
        get :show, params: { organization_id: company.id, id: public_company_observation.id }
        expect(response).to have_http_status(:success)
      end

      it 'allows manager to view' do
        sign_in_as_teammate(manager_person, company)
        get :show, params: { organization_id: company.id, id: public_company_observation.id }
        expect(response).to have_http_status(:success)
      end

      it 'allows random active teammate to view' do
        sign_in_as_teammate(random_person, company)
        get :show, params: { organization_id: company.id, id: public_company_observation.id }
        expect(response).to have_http_status(:success)
      end

      it 'redirects terminated teammate to kudos page' do
        terminated_person = create(:person)
        terminated_teammate = create(:teammate, person: terminated_person, organization: company, first_employed_at: 1.month.ago, last_terminated_at: 1.day.ago)
        sign_in_as_teammate(terminated_person, company)
        get :show, params: { organization_id: company.id, id: public_company_observation.id }
        date_part = public_company_observation.observed_at.strftime('%Y-%m-%d')
        expect(response).to redirect_to(organization_kudo_path(company, date: date_part, id: public_company_observation.id))
      end

      it 'redirects person from other company to kudos page' do
        other_company = create(:organization, :company)
        other_person = create(:person)
        create(:teammate, person: other_person, organization: other_company)
        sign_in_as_teammate(other_person, other_company)
        get :show, params: { organization_id: company.id, id: public_company_observation.id }
        date_part = public_company_observation.observed_at.strftime('%Y-%m-%d')
        expect(response).to redirect_to(organization_kudo_path(company, date: date_part, id: public_company_observation.id))
      end
    end

    context 'public_to_world privacy' do
      let(:public_world_observation) do
        obs = build(:observation, observer: observer, company: company, privacy_level: :public_to_world)
        obs.observees.build(teammate: observee_teammate)
        obs.save!
        obs.publish!
        obs
      end

      it 'allows observer to view' do
        get :show, params: { organization_id: company.id, id: public_world_observation.id }
        expect(response).to have_http_status(:success)
      end

      it 'allows observee to view' do
        sign_in_as_teammate(observee_person, company)
        get :show, params: { organization_id: company.id, id: public_world_observation.id }
        expect(response).to have_http_status(:success)
      end

      it 'allows manager to view' do
        sign_in_as_teammate(manager_person, company)
        get :show, params: { organization_id: company.id, id: public_world_observation.id }
        expect(response).to have_http_status(:success)
      end

      it 'allows random active teammate to view' do
        sign_in_as_teammate(random_person, company)
        get :show, params: { organization_id: company.id, id: public_world_observation.id }
        expect(response).to have_http_status(:success)
      end

      it 'redirects terminated teammate to kudos page' do
        terminated_person = create(:person)
        terminated_teammate = create(:teammate, person: terminated_person, organization: company, first_employed_at: 1.month.ago, last_terminated_at: 1.day.ago)
        sign_in_as_teammate(terminated_person, company)
        get :show, params: { organization_id: company.id, id: public_world_observation.id }
        date_part = public_world_observation.observed_at.strftime('%Y-%m-%d')
        expect(response).to redirect_to(organization_kudo_path(company, date: date_part, id: public_world_observation.id))
      end

      it 'redirects person from other company to kudos page' do
        other_company = create(:organization, :company)
        other_person = create(:person)
        create(:teammate, person: other_person, organization: other_company)
        sign_in_as_teammate(other_person, other_company)
        get :show, params: { organization_id: company.id, id: public_world_observation.id }
        date_part = public_world_observation.observed_at.strftime('%Y-%m-%d')
        expect(response).to redirect_to(organization_kudo_path(company, date: date_part, id: public_world_observation.id))
      end
    end
  end

  describe 'GET #new' do
    it 'renders the new form (overlay layout)' do
      get :new, params: { organization_id: company.id }
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:new)
      expect(response).to render_template(layout: 'overlay')
    end

    it 'assigns a new observation' do
      get :new, params: { organization_id: company.id }
      expect(assigns(:observation)).to be_a_new(Observation)
      expect(assigns(:observation).company_id).to eq(company.id)
      expect(assigns(:observation).observer).to eq(observer)
    end

    it 'accepts return_url and return_text params' do
      get :new, params: {
        organization_id: company.id,
        return_url: organization_observations_path(company),
        return_text: 'Back to Observations'
      }
      expect(assigns(:return_url)).to eq(organization_observations_path(company))
      expect(assigns(:return_text)).to eq('Back to Observations')
    end

    it 'sets default return_url and return_text when not provided' do
      get :new, params: { organization_id: company.id }
      expect(assigns(:return_url)).to eq(organization_observations_path(company))
      expect(assigns(:return_text)).to eq('Back')
    end

    it 'accepts draft_id to load existing draft' do
      draft = build(:observation, observer: observer, company: company, published_at: nil)
      draft.observees.build(teammate: observee_teammate)
      draft.save!
      
      get :new, params: {
        organization_id: company.id,
        draft_id: draft.id
      }
      expect(assigns(:observation)).to eq(draft)
      expect(assigns(:observation).published_at).to be_nil
    end

    it 'accepts observee_ids to pre-populate observees' do
      get :new, params: {
        organization_id: company.id,
        observee_ids: [observee_teammate.id]
      }
      expect(assigns(:observation).observees).to be_present
      expect(assigns(:observation).observees.first.teammate_id).to eq(observee_teammate.id)
    end

    it 'assigns available rateables for the organization' do
      assignment = create(:assignment, company: company)
      get :new, params: { organization_id: company.id }
      expect(assigns(:assignments)).to include(assignment)
      expect(assigns(:aspirations)).to be_a(ActiveRecord::Associations::CollectionProxy)
      expect(assigns(:abilities)).to be_a(ActiveRecord::Relation)
    end

    context 'auto-adding company aspirations' do
      let(:company_aspiration_1) { create(:aspiration, organization: company, name: 'Company Growth', sort_order: 1) }
      let(:company_aspiration_2) { create(:aspiration, organization: company, name: 'Innovation', sort_order: 2) }
      let(:company_aspiration_3) { create(:aspiration, organization: company, name: 'Customer Satisfaction', sort_order: 3) }

      before do
        company_aspiration_1
        company_aspiration_2
        company_aspiration_3
      end

      it 'automatically adds all company aspirations when no rateable params are passed' do
        get :new, params: { organization_id: company.id }
        observation = assigns(:observation)
        
        aspiration_ratings = observation.observation_ratings.select { |r| r.rateable_type == 'Aspiration' }
        expect(aspiration_ratings.count).to eq(3)
        expect(aspiration_ratings.map { |r| r.rateable_id }).to contain_exactly(
          company_aspiration_1.id,
          company_aspiration_2.id,
          company_aspiration_3.id
        )
      end

      it 'pre-loads the rateable association for each aspiration rating' do
        get :new, params: { organization_id: company.id }
        observation = assigns(:observation)
        
        aspiration_ratings = observation.observation_ratings.select { |r| r.rateable_type == 'Aspiration' }
        aspiration_ratings.each do |rating|
          expect(rating.rateable).to be_present
          expect(rating.rateable).to be_a(Aspiration)
        end
      end

      it 'does not add company aspirations when rateable_type and rateable_id are passed' do
        assignment = create(:assignment, company: company)
        get :new, params: {
          organization_id: company.id,
          rateable_type: 'Assignment',
          rateable_id: assignment.id
        }
        observation = assigns(:observation)
        
        aspiration_ratings = observation.observation_ratings.select { |r| r.rateable_type == 'Aspiration' }
        expect(aspiration_ratings.count).to eq(0)
        
        assignment_ratings = observation.observation_ratings.select { |r| r.rateable_type == 'Assignment' }
        expect(assignment_ratings.count).to eq(1)
        expect(assignment_ratings.first.rateable_id).to eq(assignment.id)
      end

      it 'does not add company aspirations when an aspiration is explicitly passed' do
        get :new, params: {
          organization_id: company.id,
          rateable_type: 'Aspiration',
          rateable_id: company_aspiration_1.id
        }
        observation = assigns(:observation)
        
        aspiration_ratings = observation.observation_ratings.select { |r| r.rateable_type == 'Aspiration' }
        expect(aspiration_ratings.count).to eq(1)
        expect(aspiration_ratings.first.rateable_id).to eq(company_aspiration_1.id)
      end

      it 'only adds root company aspirations, not department or team aspirations' do
        department = create(:organization, :department, parent: company)
        department_aspiration = create(:aspiration, organization: department, name: 'Department Goal', sort_order: 1)
        
        get :new, params: { organization_id: company.id }
        observation = assigns(:observation)
        
        aspiration_ratings = observation.observation_ratings.select { |r| r.rateable_type == 'Aspiration' }
        aspiration_ids = aspiration_ratings.map { |r| r.rateable_id }
        
        expect(aspiration_ids).to contain_exactly(
          company_aspiration_1.id,
          company_aspiration_2.id,
          company_aspiration_3.id
        )
        expect(aspiration_ids).not_to include(department_aspiration.id)
      end

      it 'handles gracefully when no company aspirations exist' do
        # Delete all aspirations
        Aspiration.destroy_all
        
        get :new, params: { organization_id: company.id }
        observation = assigns(:observation)
        
        aspiration_ratings = observation.observation_ratings.select { |r| r.rateable_type == 'Aspiration' }
        expect(aspiration_ratings.count).to eq(0)
        expect(response).to have_http_status(:success)
      end

      it 'does not add aspirations when loading an existing draft' do
        draft = build(:observation, observer: observer, company: company, published_at: nil)
        draft.observees.build(teammate: observee_teammate)
        draft.save!
        
        get :new, params: {
          organization_id: company.id,
          draft_id: draft.id
        }
        observation = assigns(:observation)
        
        aspiration_ratings = observation.observation_ratings.select { |r| r.rateable_type == 'Aspiration' }
        expect(aspiration_ratings.count).to eq(0)
      end

      it 'does not add aspirations when loading an existing published observation' do
        published_obs = build(:observation, observer: observer, company: company, published_at: Time.current)
        published_obs.observees.build(teammate: observee_teammate)
        published_obs.save!
        
        get :new, params: {
          organization_id: company.id,
          id: published_obs.id
        }
        observation = assigns(:observation)
        
        aspiration_ratings = observation.observation_ratings.select { |r| r.rateable_type == 'Aspiration' }
        expect(aspiration_ratings.count).to eq(0)
      end

      context 'when organization is a department' do
        let(:department) { create(:organization, :department, parent: company) }
        let(:department_teammate) { create(:teammate, person: observer, organization: department) }

        before do
          department_teammate
        end

        it 'uses root company aspirations even when accessed from a department' do
          get :new, params: { organization_id: department.id }
          observation = assigns(:observation)
          
          aspiration_ratings = observation.observation_ratings.select { |r| r.rateable_type == 'Aspiration' }
          expect(aspiration_ratings.count).to eq(3)
          expect(aspiration_ratings.map { |r| r.rateable_id }).to contain_exactly(
            company_aspiration_1.id,
            company_aspiration_2.id,
            company_aspiration_3.id
          )
        end
      end
    end
  end

  describe 'POST #create' do
    let(:valid_params) do
      {
        organization_id: company.id,
        observation: {
          story: 'Great work on the project!',
          privacy_level: 'observed_only',
          primary_feeling: 'happy',
          secondary_feeling: 'proud',
          observed_at: Date.current,
          observees_attributes: {
            '0' => { teammate_id: observee_teammate.id }
          }
        }
      }
    end

    context 'with valid parameters' do
      it 'creates a new observation' do
        expect {
          post :create, params: valid_params
        }.to change(Observation, :count).by(1)
      end

      it 'redirects to the observation show page' do
        post :create, params: valid_params
        observation = Observation.last
        expect(response).to redirect_to(organization_observation_path(company, observation))
      end

      it 'sets the correct attributes' do
        post :create, params: valid_params
        observation = Observation.last
        expect(observation.story).to eq('Great work on the project!')
        expect(observation.privacy_level).to eq('observed_only')
        expect(observation.primary_feeling).to eq('happy')
        expect(observation.secondary_feeling).to eq('proud')
        expect(observation.company).to be_a(Organization)
        expect(observation.observer).to eq(observer)
      end
    end

    context 'with public privacy level and negative ratings' do
      let(:ability) { create(:ability, organization: company) }
      let(:public_params_with_negative_rating) do
        {
          organization_id: company.id,
          observation: {
            story: 'Some feedback',
            privacy_level: 'public_to_world',
            primary_feeling: 'happy',
            observed_at: Date.current,
            observees_attributes: {
              '0' => { teammate_id: observee_teammate.id }
            },
            observation_ratings_attributes: {
              '0' => {
                rateable_type: 'Ability',
                rateable_id: ability.id,
                rating: 'disagree'
              }
            }
          }
        }
      end

      it 'changes privacy level to observed_and_managers' do
        post :create, params: public_params_with_negative_rating
        observation = Observation.last
        expect(observation.privacy_level).to eq('observed_and_managers')
      end

      it 'sets flash alert with privacy change message' do
        post :create, params: public_params_with_negative_rating
        expect(flash[:alert]).to include("Privacy level was changed from Public to 'For them and their managers'")
      end

      it 'still sets success notice' do
        post :create, params: public_params_with_negative_rating
        expect(flash[:notice]).to eq('Observation was successfully created.')
      end
    end

    context 'with public privacy level but only positive ratings' do
      let(:ability) { create(:ability, organization: company) }
      let(:public_params_with_positive_rating) do
        {
          organization_id: company.id,
          observation: {
            story: 'Great feedback',
            privacy_level: 'public_to_world',
            primary_feeling: 'happy',
            observed_at: Date.current,
            observees_attributes: {
              '0' => { teammate_id: observee_teammate.id }
            },
            observation_ratings_attributes: {
              '0' => {
                rateable_type: 'Ability',
                rateable_id: ability.id,
                rating: 'strongly_agree'
              }
            }
          }
        }
      end

      it 'does not change privacy level' do
        post :create, params: public_params_with_positive_rating
        observation = Observation.last
        expect(observation.privacy_level).to eq('public_to_world')
      end

      it 'does not set flash alert' do
        post :create, params: public_params_with_positive_rating
        expect(flash[:alert]).to be_nil
      end
    end

    context 'with invalid parameters' do
      let(:invalid_params) do
        {
          organization_id: company.id,
          observation: {
            story: '', # Invalid - empty story when publishing
            privacy_level: 'observed_only',
            publishing: 'true'
          }
        }
      end

      it 'does not create a new observation' do
        expect {
          post :create, params: invalid_params
        }.not_to change(Observation, :count)
      end

      it 'renders the new template' do
        post :create, params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to render_template(:new)
      end
    end
  end

  describe 'GET #new with published observation (editing)' do
    let(:published_observation) do
      obs = build(:observation, observer: observer, company: company, published_at: Time.current)
      obs.observees.build(teammate: observee_teammate)
      obs.save!
      obs
    end

    context 'when user is the observer' do
      it 'loads the published observation via id param' do
        get :new, params: {
          organization_id: company.id,
          id: published_observation.id
        }
        expect(assigns(:observation)).to eq(published_observation)
        expect(assigns(:observation).published_at).to be_present
        expect(response).to have_http_status(:success)
        expect(response).to render_template(:new)
        expect(response).to render_template(layout: 'overlay')
      end

      it 'loads the published observation via draft_id param' do
        get :new, params: {
          organization_id: company.id,
          draft_id: published_observation.id
        }
        expect(assigns(:observation)).to eq(published_observation)
        expect(assigns(:observation).published_at).to be_present
      end

      it 'sets default return_url to show page when editing published observation' do
        get :new, params: {
          organization_id: company.id,
          id: published_observation.id
        }
        expect(assigns(:return_url)).to eq(organization_observation_path(company, published_observation))
        expect(assigns(:return_text)).to eq('Back to Observation')
      end

      it 'accepts custom return_url and return_text when editing' do
        get :new, params: {
          organization_id: company.id,
          id: published_observation.id,
          return_url: organization_observations_path(company),
          return_text: 'Back to List'
        }
        expect(assigns(:return_url)).to eq(organization_observations_path(company))
        expect(assigns(:return_text)).to eq('Back to List')
      end
    end

    context 'when user is not the observer' do
      let(:other_person) { create(:person) }
      let(:other_teammate) { create(:teammate, person: other_person, organization: company) }
      
      before do
        sign_in_as_teammate(other_person, company)
      end

      it 'redirects with authorization error' do
        get :new, params: {
          organization_id: company.id,
          id: published_observation.id
        }
        
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to include("don't have permission")
      end
    end
  end

  describe 'DELETE #destroy' do
    context 'when user is the observer and within 24 hours' do
      before do
        observation.update_column(:created_at, 1.hour.ago)
      end

      it 'soft deletes the observation' do
        expect {
          delete :destroy, params: { organization_id: company.id, id: observation.id }
        }.to change { observation.reload.deleted_at }.from(nil)
      end

      it 'redirects to observations index' do
        delete :destroy, params: { organization_id: company.id, id: observation.id }
        expect(response).to redirect_to(organization_observations_path(company))
      end
    end

    context 'when user is not the observer' do
      let(:other_person) { create(:person) }
      let(:other_teammate) { create(:teammate, person: other_person, organization: company) }
      
      before do
        sign_in_as_teammate(other_person, company)
      end

      it 'redirects to kudos page' do
        delete :destroy, params: { organization_id: company.id, id: observation.id }
        date_part = observation.observed_at.strftime('%Y-%m-%d')
        expect(response).to redirect_to(organization_kudo_path(company, date: date_part, id: observation.id))
      end
    end
  end

  describe 'GET #journal' do
    let!(:journal_observation) do
      obs = build(:observation, observer: observer, company: company, privacy_level: :observer_only)
      obs.observees.build(teammate: observee_teammate)
      obs.save!
      obs
    end

    it 'renders the index page with journal filter' do
      get :journal, params: { organization_id: company.id }
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:index)
    end

    it 'assigns only journal observations' do
      get :journal, params: { organization_id: company.id }
      expect(assigns(:observations)).to include(journal_observation)
      expect(assigns(:observations)).not_to include(observation) # Non-journal observation
    end
  end

  describe 'GET #quick_new' do
    let(:assignment) { create(:assignment, company: company) }
    
    it 'redirects to new action with all parameters' do
      get :quick_new, params: {
        organization_id: company.id,
        return_url: organization_observations_path(company),
        return_text: 'Check-ins',
        observee_ids: [observee_teammate.id],
        rateable_type: 'Assignment',
        rateable_id: assignment.id,
        privacy_level: 'observed_and_managers'
      }
      expect(response).to redirect_to(new_organization_observation_path(
        company,
        return_url: organization_observations_path(company),
        return_text: 'Check-ins',
        observee_ids: [observee_teammate.id],
        rateable_type: 'Assignment',
        rateable_id: assignment.id,
        privacy_level: 'observed_and_managers'
      ))
    end
  end

  describe 'POST #add_rateables' do
    let(:draft) do
      obs = build(:observation, observer: observer, company: company, published_at: nil)
      obs.observees.build(teammate: observee_teammate)
      obs.save!
      obs
    end
    let(:assignment) { create(:assignment, company: company) }

    it 'adds rateables to the draft' do
      expect {
        post :add_rateables, params: {
          organization_id: company.id,
          id: draft.id,
          rateable_type: 'Assignment',
          rateable_ids: [assignment.id]
        }
      }.to change { draft.observation_ratings.count }.by(1)
      
      expect(draft.reload.published_at).to be_nil
    end

    it 'redirects back to new' do
      post :add_rateables, params: {
        organization_id: company.id,
        id: draft.id,
        rateable_type: 'Assignment',
        rateable_ids: [assignment.id]
      }
      expect(response).to redirect_to(new_organization_observation_path(company, draft_id: draft.id))
    end

    context 'when adding rateable to public observation with existing negative rating' do
      let(:ability) { create(:ability, organization: company) }
      let(:assignment) { create(:assignment, company: company) }
      let(:public_draft) do
        obs = build(:observation, observer: observer, company: company, published_at: nil, privacy_level: :public_to_world)
        obs.observees.build(teammate: observee_teammate)
        obs.save!
        # Create existing negative rating
        create(:observation_rating, observation: obs, rateable: ability, rating: :disagree)
        obs
      end

      it 'maintains observed_and_managers privacy level after adding another rateable' do
        # Privacy should already be changed due to existing negative rating
        expect(public_draft.privacy_level).to eq('public_to_world')
        
        post :add_rateables, params: {
          organization_id: company.id,
          id: public_draft.id,
          rateable_type: 'Assignment',
          rateable_ids: [assignment.id]
        }
        # Service should detect negative rating and change privacy
        expect(public_draft.reload.privacy_level).to eq('observed_and_managers')
      end
    end
  end

  describe 'PATCH #update_draft' do
    let(:draft) do
      obs = build(:observation, observer: observer, company: company, published_at: nil)
      obs.observees.build(teammate: observee_teammate)
      obs.save!
      obs
    end

    it 'updates the draft observation' do
      patch :update_draft, params: {
        organization_id: company.id,
        id: draft.id,
        observation: {
          story: 'Updated story',
          primary_feeling: 'excited'
        }
      }
      draft.reload
      expect(draft.story).to eq('Updated story')
      expect(draft.primary_feeling).to eq('excited')
      expect(draft.published_at).to be_nil
    end

    it 'saves story_extras with gif_urls' do
      patch :update_draft, params: {
        organization_id: company.id,
        id: draft.id,
        observation: {
          story: 'Test story',
          privacy_level: 'observer_only',
          story_extras: {
            gif_urls: ['https://media.giphy.com/media/test1/giphy.gif', 'https://media.giphy.com/media/test2/giphy.gif']
          }
        }
      }
      draft.reload
      expect(draft.story_extras).to eq({ 'gif_urls' => ['https://media.giphy.com/media/test1/giphy.gif', 'https://media.giphy.com/media/test2/giphy.gif'] })
    end


    context 'when saving a published observation as draft' do
      let(:published_observation) do
        obs = build(:observation, observer: observer, company: company, published_at: 1.day.ago)
        obs.observees.build(teammate: observee_teammate)
        obs.save!
        obs
      end

      it 'converts published observation to draft when save_draft_and_return is present' do
        expect(published_observation.published_at).to be_present
        
        patch :update_draft, params: {
          organization_id: company.id,
          id: published_observation.id,
          save_draft_and_return: '1',
          observation: {
            story: 'Updated story',
            primary_feeling: 'excited'
          },
          return_url: organization_observations_path(company)
        }
        
        published_observation.reload
        expect(published_observation.published_at).to be_nil
        expect(published_observation.draft?).to be true
      end
    end
  end

  describe 'POST #publish' do
    let(:draft) do
      obs = build(:observation, observer: observer, company: company, published_at: nil)
      obs.observees.build(teammate: observee_teammate)
      obs.save!
      obs
    end

    it 'sets published_at timestamp' do
      post :publish, params: {
        organization_id: company.id,
        id: draft.id,
        return_url: organization_observations_path(company)
      }
      draft.reload
      expect(draft.published_at).to be_present
    end

    it 'redirects to return_url with show_observations_for param' do
      post :publish, params: {
        organization_id: company.id,
        id: draft.id,
        return_url: organization_observations_path(company),
        show_observations_for: 'assignment_123'
      }
      expect(response).to redirect_to(organization_observations_path(company) + '?show_observations_for=assignment_123')
    end

    it 'redirects to show page when return_url is not provided (publish from show page)' do
      post :publish, params: {
        organization_id: company.id,
        id: draft.id
      }
      expect(response).to redirect_to(organization_observation_path(company, draft))
    end

    it 'fails gracefully if validation errors occur when publishing from show page' do
      # Create a draft without required fields
      invalid_draft = build(:observation, observer: observer, company: company, published_at: nil, story: nil)
      invalid_draft.observees.build(teammate: observee_teammate)
      invalid_draft.save!
      
      post :publish, params: {
        organization_id: company.id,
        id: invalid_draft.id
      }
      invalid_draft.reload
      expect(invalid_draft.published_at).to be_nil
      expect(response).to redirect_to(organization_observation_path(company, invalid_draft))
      expect(flash[:alert]).to be_present
    end

    context 'with public privacy level and negative ratings' do
      let(:ability) { create(:ability, organization: company) }
      let(:draft_with_negative_rating) do
        obs = build(:observation, observer: observer, company: company, published_at: nil, privacy_level: :public_to_world)
        obs.observees.build(teammate: observee_teammate)
        obs.save!
        create(:observation_rating, observation: obs, rateable: ability, rating: :disagree)
        obs
      end

      it 'changes privacy level to observed_and_managers' do
        post :publish, params: {
          organization_id: company.id,
          id: draft_with_negative_rating.id
        }
        expect(draft_with_negative_rating.reload.privacy_level).to eq('observed_and_managers')
      end

      it 'sets flash alert with privacy change message' do
        post :publish, params: {
          organization_id: company.id,
          id: draft_with_negative_rating.id
        }
        expect(flash[:alert]).to include("Privacy level was changed from Public to 'For them and their managers'")
      end

      it 'still sets success notice' do
        post :publish, params: {
          organization_id: company.id,
          id: draft_with_negative_rating.id
        }
        expect(flash[:notice]).to eq('Observation was successfully published.')
      end
    end

    context 'with public privacy level but no ratings' do
      let(:draft_without_ratings) do
        obs = build(:observation, observer: observer, company: company, published_at: nil, privacy_level: :public_to_world)
        obs.observees.build(teammate: observee_teammate)
        obs.save!
        obs
      end

      it 'does not change privacy level' do
        post :publish, params: {
          organization_id: company.id,
          id: draft_without_ratings.id
        }
        expect(draft_without_ratings.reload.privacy_level).to eq('public_to_world')
      end

      it 'does not set flash alert' do
        post :publish, params: {
          organization_id: company.id,
          id: draft_without_ratings.id
        }
        expect(flash[:alert]).to be_nil
      end
    end
  end

  describe 'GET #manage_observees' do
    let(:draft) do
      obs = build(:observation, observer: observer, company: company, published_at: nil)
      obs.observees.build(teammate: observee_teammate)
      obs.save!
      obs
    end
    let!(:other_teammate) { create(:teammate, organization: company) }

    it 'renders the manage_observees template' do
      get :manage_observees, params: { organization_id: company.id, id: draft.id }
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:manage_observees)
      expect(response).to render_template(layout: 'overlay')
    end

    it 'assigns all teammates (not just unselected)' do
      get :manage_observees, params: { organization_id: company.id, id: draft.id }
      teammate_ids = assigns(:teammates).pluck(:id)
      expect(teammate_ids).to include(observee_teammate.id)
      expect(teammate_ids).to include(other_teammate.id)
    end

    it 'requires authorization' do
      other_person = create(:person)
      other_teammate_user = create(:teammate, person: other_person, organization: company)
      sign_in_as_teammate(other_person, company)
      
      get :manage_observees, params: { organization_id: company.id, id: draft.id }
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to be_present
    end
  end

  describe 'PATCH #manage_observees' do
    let(:draft) do
      # Build observation without factory callback to avoid extra observee
      obs = Observation.new(observer: observer, company: company, published_at: nil, privacy_level: :observed_only, primary_feeling: 'happy', observed_at: Time.current)
      obs.observees.build(teammate: observee_teammate)
      obs.save!
      obs
    end
    let(:new_teammate) { create(:teammate, organization: company) }
    let(:another_teammate) { create(:teammate, organization: company) }

    context 'when adding new observees' do
      it 'adds new observees when teammates are checked' do
        expect {
          patch :manage_observees, params: {
            organization_id: company.id,
            id: draft.id,
            teammate_ids: [observee_teammate.id, new_teammate.id]
          }
        }.to change { draft.observees.count }.by(1)
        
        expect(draft.reload.observees.pluck(:teammate_id)).to include(observee_teammate.id, new_teammate.id)
      end

      it 'shows appropriate success message when adding' do
        patch :manage_observees, params: {
          organization_id: company.id,
          id: draft.id,
          teammate_ids: [observee_teammate.id, new_teammate.id]
        }
        expect(flash[:notice]).to include('Added 1 observee(s)')
      end
    end

    context 'when removing observees' do
      it 'removes observees when teammates are unchecked' do
        expect {
          patch :manage_observees, params: {
            organization_id: company.id,
            id: draft.id,
            teammate_ids: []
          }
        }.to change { draft.observees.count }.by(-1)
        
        expect(draft.reload.observees.pluck(:teammate_id)).not_to include(observee_teammate.id)
      end

      it 'shows appropriate success message when removing' do
        patch :manage_observees, params: {
          organization_id: company.id,
          id: draft.id,
          teammate_ids: []
        }
        expect(flash[:notice]).to include('Removed 1 observee(s)')
      end
    end

    context 'when adding and removing in same submission' do
      before do
        draft.observees.create!(teammate: another_teammate)
      end

      it 'handles mixed add/remove in single submission' do
        expect {
          patch :manage_observees, params: {
            organization_id: company.id,
            id: draft.id,
            teammate_ids: [observee_teammate.id, new_teammate.id]
          }
        }.to change { draft.observees.count }.by(0) # One removed, one added
        
        expect(draft.reload.observees.pluck(:teammate_id)).to include(observee_teammate.id, new_teammate.id)
        expect(draft.reload.observees.pluck(:teammate_id)).not_to include(another_teammate.id)
      end

      it 'shows appropriate success message for mixed operations' do
        patch :manage_observees, params: {
          organization_id: company.id,
          id: draft.id,
          teammate_ids: [observee_teammate.id, new_teammate.id]
        }
        expect(flash[:notice]).to include('Added 1 observee(s) and removed 1 observee(s)')
      end
    end

    context 'when no changes are made' do
      it 'shows no changes message' do
        patch :manage_observees, params: {
          organization_id: company.id,
          id: draft.id,
          teammate_ids: [observee_teammate.id]
        }
        expect(flash[:notice]).to eq('No changes made')
      end
    end

    context 'edge cases' do
      it 'handles empty selection (all removed)' do
        expect {
          patch :manage_observees, params: {
            organization_id: company.id,
            id: draft.id,
            teammate_ids: []
          }
        }.to change { draft.observees.count }.by(-1)
      end

      it 'handles all teammates selected (all added)' do
        new_teammate2 = create(:teammate, organization: company)
        expect {
          patch :manage_observees, params: {
            organization_id: company.id,
            id: draft.id,
            teammate_ids: [observee_teammate.id, new_teammate.id, new_teammate2.id]
          }
        }.to change { draft.observees.count }.by(2)
      end

      it 'redirects back to new observation page with correct params' do
        patch :manage_observees, params: {
          organization_id: company.id,
          id: draft.id,
          teammate_ids: [observee_teammate.id],
          return_url: organization_observations_path(company),
          return_text: 'Back to Observations'
        }
        expect(response).to redirect_to(new_organization_observation_path(
          company,
          draft_id: draft.id,
          return_url: organization_observations_path(company),
          return_text: 'Back to Observations'
        ))
      end
    end

    it 'requires authorization' do
      other_person = create(:person)
      other_teammate_user = create(:teammate, person: other_person, organization: company)
      sign_in_as_teammate(other_person, company)
      
      patch :manage_observees, params: {
        organization_id: company.id,
        id: draft.id,
        teammate_ids: []
      }
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to be_present
    end
  end

  describe 'GET #filtered_observations' do
    let(:assignment) { create(:assignment, company: company) }
    let(:aspiration) { create(:aspiration, organization: company) }
    let(:ability) { create(:ability, organization: company) }
    
    let!(:published_observation) do
      obs = build(:observation, observer: observer, company: company, observed_at: 2.days.ago, story: 'Published observation story')
      obs.observees.build(teammate: observee_teammate)
      obs.save!
      obs.publish!
      obs
    end
    
    let!(:draft_observation) do
      obs = build(:observation, observer: observer, company: company, published_at: nil, observed_at: 1.day.ago, story: 'Draft observation story')
      obs.observees.build(teammate: observee_teammate)
      obs.save!
      obs
    end
    
    let!(:deleted_observation) do
      obs = build(:observation, observer: observer, company: company, observed_at: 3.days.ago)
      obs.observees.build(teammate: observee_teammate)
      obs.save!
      obs.publish!
      obs.update_column(:deleted_at, 1.day.ago)
      obs
    end
    
    let!(:other_company_observation) do
      other_company = create(:organization, :company)
      obs = build(:observation, observer: observer, company: other_company)
      obs.observees.build(teammate: create(:teammate, person: observee_person, organization: other_company))
      obs.save!
      obs.publish!
      obs
    end
    
    let!(:assignment_observation) do
      obs = build(:observation, observer: observer, company: company, observed_at: 2.days.ago)
      obs.observees.build(teammate: observee_teammate)
      obs.save!
      obs.observation_ratings.create!(rateable_type: 'Assignment', rateable_id: assignment.id)
      obs.publish!
      obs
    end
    
    let!(:aspiration_observation) do
      obs = build(:observation, observer: observer, company: company, observed_at: 2.days.ago)
      obs.observees.build(teammate: observee_teammate)
      obs.save!
      obs.observation_ratings.create!(rateable_type: 'Aspiration', rateable_id: aspiration.id)
      obs.publish!
      obs
    end
    
    let!(:ability_observation) do
      obs = build(:observation, observer: observer, company: company, observed_at: 2.days.ago)
      obs.observees.build(teammate: observee_teammate)
      obs.save!
      obs.observation_ratings.create!(rateable_type: 'Ability', rateable_id: ability.id)
      obs.publish!
      obs
    end
    
    let!(:old_observation) do
      obs = build(:observation, observer: observer, company: company, observed_at: 1.year.ago - 1.day)
      obs.observees.build(teammate: observee_teammate)
      obs.save!
      obs.publish!
      obs
    end
    
    let!(:recent_observation) do
      obs = build(:observation, observer: observer, company: company, observed_at: 1.day.ago)
      obs.observees.build(teammate: observee_teammate)
      obs.save!
      obs.publish!
      obs
    end
    
    context 'base scope (visibility query)' do
      it 'uses ObservationVisibilityQuery to filter visible observations' do
        get :filtered_observations, params: { organization_id: company.id }
        expect(response).to have_http_status(:success)
        expect(response).to render_template(:filtered_observations)
        expect(response).to render_template(layout: 'overlay')
        # Check that the view renders something (not empty)
        expect(response.body).not_to be_empty
      end
      
      it 'renders published observations visible to the user' do
        get :filtered_observations, params: { organization_id: company.id }
        # The view should render the observation story if it's visible
        expect(response.body).to include(published_observation.story)
      end
      
      it 'renders draft observations created by the user' do
        get :filtered_observations, params: { organization_id: company.id }
        expect(response.body).to include(draft_observation.story)
      end
      
      it 'excludes deleted observations from rendered output' do
        get :filtered_observations, params: { organization_id: company.id }
        expect(response.body).not_to include(deleted_observation.story)
      end
      
      it 'excludes observations from other organizations' do
        get :filtered_observations, params: { organization_id: company.id }
        expect(response.body).not_to include(other_company_observation.story)
      end
      
      context 'when user is not the observer' do
        let(:other_person) { create(:person) }
        let!(:other_teammate) { create(:teammate, person: other_person, organization: company) }
        
        before do
          sign_in_as_teammate(other_person, company)
        end
        
        it 'excludes draft observations created by others' do
          get :filtered_observations, params: { organization_id: company.id }
          expect(response.body).not_to include(draft_observation.story)
        end
        
        it 'includes published observations visible to the user' do
          # Create a published observation visible to other_person
          visible_obs = build(:observation, observer: observer, company: company, privacy_level: :public_to_world, story: 'Visible to other person')
          visible_obs.observees.build(teammate: other_teammate)
          visible_obs.save!
          visible_obs.publish!
          
          get :filtered_observations, params: { organization_id: company.id }
          expect(response.body).to include('Visible to other person')
        end
      end
    end
    
    context 'filtering by rateable_type and rateable_id' do
      before do
        assignment_observation.update!(story: 'Assignment observation story')
        aspiration_observation.update!(story: 'Aspiration observation story')
        ability_observation.update!(story: 'Ability observation story')
      end
      
      it 'filters observations by Assignment' do
        get :filtered_observations, params: {
          organization_id: company.id,
          rateable_type: 'Assignment',
          rateable_id: assignment.id
        }
        expect(response.body).to include('Assignment observation story')
        expect(response.body).not_to include('Aspiration observation story', 'Ability observation story')
      end
      
      it 'filters observations by Aspiration' do
        get :filtered_observations, params: {
          organization_id: company.id,
          rateable_type: 'Aspiration',
          rateable_id: aspiration.id
        }
        expect(response.body).to include('Aspiration observation story')
        expect(response.body).not_to include('Assignment observation story', 'Ability observation story')
      end
      
      it 'filters observations by Ability' do
        get :filtered_observations, params: {
          organization_id: company.id,
          rateable_type: 'Ability',
          rateable_id: ability.id
        }
        expect(response.body).to include('Ability observation story')
        expect(response.body).not_to include('Assignment observation story', 'Aspiration observation story')
      end
      
      it 'returns empty when no observations match the rateable' do
        other_assignment = create(:assignment, company: company)
        get :filtered_observations, params: {
          organization_id: company.id,
          rateable_type: 'Assignment',
          rateable_id: other_assignment.id
        }
        expect(response.body).not_to include('Assignment observation story')
        expect(response.body).to include('No observations found')
      end
    end
    
    context 'filtering by observee_ids' do
      let(:other_teammate) { create(:teammate, organization: company) }
      
      let!(:other_observee_observation) do
        obs = build(:observation, observer: observer, company: company, story: 'Other observee observation')
        obs.observees.build(teammate: other_teammate)
        obs.save!
        obs.publish!
        obs
      end
      
      before do
        published_observation.update!(story: 'Published observation for observee')
      end
      
      it 'filters observations by observee_ids' do
        get :filtered_observations, params: {
          organization_id: company.id,
          observee_ids: [observee_teammate.id]
        }
        expect(response.body).to include('Published observation for observee')
        expect(response.body).not_to include('Other observee observation')
      end
      
      it 'handles multiple observee_ids' do
        get :filtered_observations, params: {
          organization_id: company.id,
          observee_ids: [observee_teammate.id, other_teammate.id]
        }
        expect(response.body).to include('Published observation for observee', 'Other observee observation')
      end
    end
    
    context 'filtering by start_date' do
      before do
        recent_observation.update!(story: 'Recent observation')
        old_observation.update!(story: 'Old observation')
      end
      
      it 'filters observations by start_date' do
        start_date = 1.week.ago
        get :filtered_observations, params: {
          organization_id: company.id,
          start_date: start_date.iso8601
        }
        expect(response.body).to include('Recent observation')
        expect(response.body).not_to include('Old observation')
      end
      
      it 'handles date parsing errors gracefully' do
        get :filtered_observations, params: {
          organization_id: company.id,
          start_date: 'invalid-date'
        }
        expect(response).to have_http_status(:success)
        # Should not crash, just ignore invalid date
      end
    end
    
    context 'filtering by end_date' do
      before do
        recent_observation.update!(story: 'Recent observation')
        old_observation.update!(story: 'Old observation')
      end
      
      it 'filters observations by end_date' do
        end_date = 1.week.ago
        get :filtered_observations, params: {
          organization_id: company.id,
          end_date: end_date.iso8601
        }
        expect(response.body).to include('Old observation')
        expect(response.body).not_to include('Recent observation')
      end
    end
    
    context 'combined filters' do
      before do
        assignment_observation.update!(story: 'Assignment observation')
        aspiration_observation.update!(story: 'Aspiration observation')
        old_observation.update!(story: 'Old observation')
      end
      
      it 'applies all filters together' do
        start_date = 1.week.ago
        get :filtered_observations, params: {
          organization_id: company.id,
          rateable_type: 'Assignment',
          rateable_id: assignment.id,
          observee_ids: [observee_teammate.id],
          start_date: start_date.iso8601
        }
        expect(response.body).to include('Assignment observation')
        expect(response.body).not_to include('Aspiration observation', 'Old observation')
      end
    end
    
    context 'title generation' do
      it 'generates title from rateable when rateable_type and rateable_id are provided' do
        get :filtered_observations, params: {
          organization_id: company.id,
          rateable_type: 'Assignment',
          rateable_id: assignment.id
        }
        expect(assigns(:modal_title)).to include(assignment.title)
      end
      
      it 'generates title from observee when only observee_ids are provided' do
        get :filtered_observations, params: {
          organization_id: company.id,
          observee_ids: [observee_teammate.id]
        }
        expect(assigns(:modal_title)).to include(observee_person.display_name)
      end
      
      it 'uses default title when no filters are provided' do
        get :filtered_observations, params: { organization_id: company.id }
        expect(assigns(:modal_title)).to eq('Observations')
      end
    end
    
    context 'return URL handling' do
      it 'uses provided return_url and return_text' do
        return_url = organization_observations_path(company)
        return_text = 'Back to Observations'
        get :filtered_observations, params: {
          organization_id: company.id,
          return_url: return_url,
          return_text: return_text
        }
        expect(assigns(:return_url)).to eq(return_url)
        expect(assigns(:return_text)).to eq(return_text)
      end
      
      it 'uses defaults when return_url and return_text are not provided' do
        get :filtered_observations, params: { organization_id: company.id }
        expect(assigns(:return_url)).to eq(organization_observations_path(company))
        expect(assigns(:return_text)).to eq('Back to Observations')
      end
    end
    
    context 'authorization' do
      it 'requires authorization' do
        other_person = create(:person)
        other_company = create(:organization, :company)
        sign_in_as_teammate(other_person, other_company)
        
        get :filtered_observations, params: { organization_id: company.id }
        # Authorization prevents access when user doesn't have a teammate in the target organization
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(organizations_path)
      end
    end
    
    context 'edge cases' do
      it 'handles empty observee_ids array' do
        get :filtered_observations, params: {
          organization_id: company.id,
          observee_ids: []
        }
        expect(response).to have_http_status(:success)
      end
      
      it 'handles non-existent rateable_id gracefully' do
        get :filtered_observations, params: {
          organization_id: company.id,
          rateable_type: 'Assignment',
          rateable_id: 99999
        }
        expect(response).to have_http_status(:success)
        # Should not crash, just return empty results
      end
      
      it 'handles invalid rateable_type gracefully' do
        expect {
          get :filtered_observations, params: {
            organization_id: company.id,
            rateable_type: 'InvalidType',
            rateable_id: 1
          }
        }.to raise_error(NameError) # constantize will fail
      end
    end
  end

  describe 'GET #customize_view' do
    it 'renders the customize_view template with overlay layout' do
      get :customize_view, params: { organization_id: company.id }
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:customize_view)
      expect(response).to render_template(layout: 'overlay')
    end

    it 'assigns current filters, sort, view, and spotlight from params' do
      get :customize_view, params: {
        organization_id: company.id,
        privacy: ['observer_only', 'public_to_world'],
        timeframe: 'this_week',
        sort: 'ratings_count_desc',
        view: 'cards',
        spotlight: 'team_wins'
      }
      expect(assigns(:current_filters)[:privacy]).to include('observer_only', 'public_to_world')
      expect(assigns(:current_filters)[:timeframe]).to eq('this_week')
      expect(assigns(:current_sort)).to eq('ratings_count_desc')
      expect(assigns(:current_view)).to eq('cards')
      expect(assigns(:current_spotlight)).to eq('team_wins')
    end

    it 'sets default values when params are not provided' do
      get :customize_view, params: { organization_id: company.id }
      expect(assigns(:current_sort)).to eq('observed_at_desc')
      expect(assigns(:current_view)).to eq('table')
      expect(assigns(:current_spotlight)).to eq('overview')
    end

    it 'sets return_url and return_text' do
      get :customize_view, params: { organization_id: company.id }
      expect(assigns(:return_url)).to include(organization_observations_path(company))
      expect(assigns(:return_text)).to eq('Back to Culture of Feedback and Recognition')
    end

    it 'preserves current params in return_url' do
      get :customize_view, params: {
        organization_id: company.id,
        privacy: ['observer_only'],
        timeframe: 'this_month'
      }
      return_url = assigns(:return_url)
      expect(return_url).to include('privacy')
      expect(return_url).to include('observer_only')
      expect(return_url).to include('timeframe=this_month')
    end

    it 'requires authorization' do
      other_person = create(:person)
      other_company = create(:organization, :company)
      sign_in_as_teammate(other_person, other_company)
      
      get :customize_view, params: { organization_id: company.id }
      expect(response).to have_http_status(:redirect)
    end
  end

  describe 'PATCH #update_view' do
    it 'redirects to index with view customization params' do
      patch :update_view, params: {
        organization_id: company.id,
        privacy: ['observer_only'],
        timeframe: 'this_week',
        sort: 'ratings_count_desc',
        view: 'cards',
        spotlight: 'team_wins'
      }
      expect(response).to have_http_status(:redirect)
      redirect_url = response.redirect_url
      expect(redirect_url).to include(organization_observations_path(company))
      expect(redirect_url).to include('privacy')
      expect(redirect_url).to include('observer_only')
      expect(redirect_url).to include('timeframe=this_week')
      expect(redirect_url).to include('sort=ratings_count_desc')
      expect(redirect_url).to include('view=cards')
      expect(redirect_url).to include('spotlight=team_wins')
    end

    it 'excludes Rails internal params from redirect' do
      patch :update_view, params: {
        organization_id: company.id,
        authenticity_token: 'token',
        _method: 'patch',
        commit: 'Apply View',
        view: 'list'
      }
      redirect_url = response.redirect_url
      expect(redirect_url).not_to include('authenticity_token')
      expect(redirect_url).not_to include('_method')
      expect(redirect_url).not_to include('commit')
      expect(redirect_url).to include('view=list')
    end

    it 'requires authorization' do
      other_person = create(:person)
      other_company = create(:organization, :company)
      sign_in_as_teammate(other_person, other_company)
      
      patch :update_view, params: { organization_id: company.id, view: 'cards' }
      expect(response).to have_http_status(:redirect)
    end
  end

  describe '#calculate_spotlight_stats with feedback_health' do
    let!(:published_observation) do
      obs = build(:observation, observer: observer, company: company, privacy_level: :public_to_world, observed_at: 1.week.ago)
      obs.observees.build(teammate: observee_teammate)
      obs.save!
      obs.publish!
      obs
    end

    let!(:journal_observation) do
      obs = build(:observation, observer: observer, company: company, privacy_level: :observer_only, observed_at: 2.weeks.ago)
      obs.observees.build(teammate: observee_teammate)
      obs.save!
      obs.publish!
      obs
    end

    let!(:old_observation) do
      obs = build(:observation, observer: observer, company: company, privacy_level: :public_to_world, observed_at: 4.months.ago)
      obs.observees.build(teammate: observee_teammate)
      obs.save!
      obs.publish!
      obs
    end

    before do
      controller.instance_variable_set(:@current_spotlight, 'feedback_health')
      controller.instance_variable_set(:@organization, company)
      allow(controller).to receive(:organization).and_return(company)
      allow(controller).to receive(:current_person).and_return(observer)
    end

    it 'calculates matrix stats for all privacy levels and timeframes' do
      stats = controller.send(:calculate_feedback_health_stats)
      
      expect(stats).to have_key(:matrix)
      expect(stats[:matrix]).to have_key('observer_only')
      expect(stats[:matrix]).to have_key('public_to_company')
      expect(stats[:matrix]).to have_key('public_to_world')
      
      # Check that each privacy level has timeframe data
      stats[:matrix].each do |privacy_level, timeframes|
        expect(timeframes).to have_key('three_weeks')
        expect(timeframes).to have_key('three_months')
        expect(timeframes).to have_key('all_time')
        
        timeframes.each do |timeframe, counts|
          expect(counts).to have_key(:created)
          expect(counts).to have_key(:published)
          expect(counts).to have_key(:notified)
        end
      end
    end

    it 'includes given_stats and received_stats' do
      stats = controller.send(:calculate_feedback_health_stats)
      
      expect(stats).to have_key(:given_stats)
      expect(stats).to have_key(:received_stats)
      
      ['three_weeks', 'three_months', 'all_time'].each do |timeframe|
        expect(stats[:given_stats][timeframe]).to have_key(:given_any)
        expect(stats[:given_stats][timeframe]).to have_key(:given_positive)
        expect(stats[:given_stats][timeframe]).to have_key(:given_constructive)
        
        expect(stats[:received_stats][timeframe]).to have_key(:received_any)
        expect(stats[:received_stats][timeframe]).to have_key(:received_positive)
        expect(stats[:received_stats][timeframe]).to have_key(:received_constructive)
      end
    end

    it 'queries all observations for the organization regardless of visibility' do
      # Create an observation that might not be visible to the current user
      other_person = create(:person)
      other_teammate = create(:teammate, person: other_person, organization: company)
      hidden_obs = build(:observation, observer: other_person, company: company, privacy_level: :observer_only, observed_at: 1.week.ago)
      hidden_obs.observees.build(teammate: observee_teammate)
      hidden_obs.save!
      hidden_obs.publish!
      
      stats = controller.send(:calculate_feedback_health_stats)
      
      # Should include the hidden observation in counts
      expect(stats[:matrix]['observer_only']['three_weeks'][:created]).to be >= 2
    end
  end

  # Note: CSRF protection is disabled in test environment (config/environments/test.rb)
  # System specs won't catch CSRF issues because allow_forgery_protection = false
  # This is expected Rails behavior - tests don't validate CSRF tokens
end
