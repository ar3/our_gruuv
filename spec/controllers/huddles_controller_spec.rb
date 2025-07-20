require 'rails_helper'

RSpec.describe HuddlesController, type: :controller do
  let(:company) { Company.create!(name: 'Test Company') }
  let(:team) { Team.create!(name: 'Test Team', parent: company) }
  let(:huddle) do
    Huddle.create!(
      organization: team,
      started_at: Time.current,
      huddle_alias: 'test-huddle'
    )
  end

  before do
    # Clear any existing test data
    Huddle.destroy_all
    Person.destroy_all
    Company.destroy_all
  end

  describe 'GET #index' do
    it 'returns http success' do
      get :index
      expect(response).to have_http_status(:success)
    end

    it 'assigns @huddles' do
      get :index
      expect(assigns(:huddles)).to be_a(ActiveRecord::Relation)
    end
  end

  describe 'GET #new' do
    it 'returns http success' do
      get :new
      expect(response).to have_http_status(:success)
    end

    it 'assigns a new huddle' do
      get :new
      expect(assigns(:huddle)).to be_a_new(Huddle)
    end
  end

  describe 'POST #create' do
    let(:valid_params) do
      {
        huddle: {
          company_name: 'Acme Corp',
          team_name: 'Engineering',
          huddle_alias: 'Sprint Planning',
          name: 'John Doe',
          email: 'john@example.com'
        }
      }
    end

    context 'with valid parameters' do
      it 'creates a new huddle' do
        expect {
          post :create, params: valid_params
        }.to change(Huddle, :count).by(1)
      end

      it 'creates a new company' do
        expect {
          post :create, params: valid_params
        }.to change(Company, :count).by(1)
      end

      it 'creates a new team' do
        expect {
          post :create, params: valid_params
        }.to change(Team, :count).by(1)
      end

      it 'creates a new person' do
        expect {
          post :create, params: valid_params
        }.to change(Person, :count).by(1)
      end

      it 'creates a huddle participant' do
        expect {
          post :create, params: valid_params
        }.to change(HuddleParticipant, :count).by(1)
      end

      it 'sets the participant as facilitator' do
        post :create, params: valid_params
        huddle = Huddle.last
        participant = huddle.huddle_participants.first
        expect(participant.role).to eq('facilitator')
      end

      it 'redirects to the huddle show page' do
        post :create, params: valid_params
        expect(response).to redirect_to(Huddle.last)
      end

      it 'sets a success notice' do
        post :create, params: valid_params
        expect(flash[:notice]).to eq('Huddle created successfully!')
      end
    end

    context 'with company only (no team)' do
      let(:company_only_params) do
        {
          huddle: {
            company_name: 'Acme Corp',
            team_name: '',
            huddle_alias: '',
            name: 'John Doe',
            email: 'john@example.com'
          }
        }
      end

      it 'creates huddle under the company' do
        post :create, params: company_only_params
        huddle = Huddle.last
        expect(huddle.organization).to be_a(Company)
        expect(huddle.organization.name).to eq('Acme Corp')
      end
    end

    context 'with existing company and team' do
      let!(:company) { Company.create!(name: 'Acme Corp') }
      let!(:team) { Team.create!(name: 'Engineering', parent: company) }

      it 'uses existing company and team' do
        expect {
          post :create, params: valid_params
        }.not_to change(Company, :count)
      end

      it 'uses existing team' do
        expect {
          post :create, params: valid_params
        }.not_to change(Team, :count)
      end
    end

    context 'with existing person' do
      let!(:person) { Person.create!(email: 'john@example.com', full_name: 'John Doe') }

      it 'uses existing person' do
        expect {
          post :create, params: valid_params
        }.not_to change(Person, :count)
      end
    end

    context 'with duplicate huddle for same organization on same day with same alias' do
      let!(:company) { Company.create!(name: 'Acme Corp') }
      let!(:team) { Team.create!(name: 'Engineering', parent: company) }
      let!(:existing_person) { Person.create!(email: 'jane@example.com', full_name: 'Jane Doe', unique_textable_phone_number: '+12345678904') }
      let!(:existing_huddle) { Huddle.create!(organization: team, started_at: Time.current, huddle_alias: 'Sprint Planning') }
      let!(:existing_participant) { HuddleParticipant.create!(huddle: existing_huddle, person: existing_person, role: 'facilitator') }

      it 'redirects to existing huddle and adds person as participant' do
        expect {
          post :create, params: valid_params
        }.not_to change(Huddle, :count)

        expect(response).to redirect_to(existing_huddle)
        expect(flash[:notice]).to eq("You've joined the existing huddle for today!")
        
        # Check that the person was added as a participant
        new_participant = existing_huddle.huddle_participants.find_by(person: Person.find_by(email: 'john@example.com'))
        expect(new_participant).to be_present
        expect(new_participant.role).to eq('active')
      end
    end

    context 'with duplicate huddle for same organization on same day without alias' do
      let(:no_alias_params) do
        {
          huddle: {
            company_name: 'Acme Corp',
            team_name: 'Engineering',
            huddle_alias: '',
            name: 'John Doe',
            email: 'john@example.com'
          }
        }
      end
      let!(:company) { Company.create!(name: 'Acme Corp') }
      let!(:team) { Team.create!(name: 'Engineering', parent: company) }
      let!(:existing_person) { Person.create!(email: 'jane@example.com', full_name: 'Jane Doe', unique_textable_phone_number: '+12345678904') }
      let!(:existing_huddle) { Huddle.create!(organization: team, started_at: Time.current, huddle_alias: nil) }
      let!(:existing_participant) { HuddleParticipant.create!(huddle: existing_huddle, person: existing_person, role: 'facilitator') }

      it 'redirects to existing huddle and adds person as participant' do
        expect {
          post :create, params: no_alias_params
        }.not_to change(Huddle, :count)

        expect(response).to redirect_to(existing_huddle)
        expect(flash[:notice]).to eq("You've joined the existing huddle for today!")
        
        # Check that the person was added as a participant
        new_participant = existing_huddle.huddle_participants.find_by(person: Person.find_by(email: 'john@example.com'))
        expect(new_participant).to be_present
        expect(new_participant.role).to eq('active')
      end
    end

    context 'with invalid parameters' do
      let(:invalid_params) do
        {
          huddle: {
            company_name: '',
            team_name: '',
            huddle_alias: '',
            name: '',
            email: 'invalid-email'
          }
        }
      end

      it 'does not create a huddle' do
        expect {
          post :create, params: invalid_params
        }.not_to change(Huddle, :count)
      end

      it 'renders the new template' do
        post :create, params: invalid_params
        expect(response).to render_template(:new)
      end
    end
  end

  describe 'GET #show' do
    let(:company) { Company.create!(name: 'Acme Corp') }
    let(:team) { Team.create!(name: 'Engineering', parent: company) }
    let(:huddle) { Huddle.create!(organization: team, started_at: Time.current) }

    it 'returns http success' do
      get :show, params: { id: huddle.id }
      expect(response).to have_http_status(:success)
    end

    it 'assigns the requested huddle' do
      get :show, params: { id: huddle.id }
      expect(assigns(:huddle)).to eq(huddle)
    end
  end

  describe 'GET #join' do
    context 'when huddle exists' do
      it 'assigns the huddle' do
        get :join, params: { id: huddle.id }
        expect(assigns(:huddle)).to eq(huddle)
      end

      it 'assigns current_person from session' do
        person = Person.create!(full_name: 'John Doe', email: 'john@example.com')
        session[:current_person_id] = person.id
        
        get :join, params: { id: huddle.id }
        expect(assigns(:current_person)).to eq(person)
      end

      it 'assigns existing_participant when user is logged in' do
        person = Person.create!(full_name: 'Jane Smith', email: 'jane@example.com')
        participant = huddle.huddle_participants.create!(person: person, role: 'active')
        session[:current_person_id] = person.id
        
        get :join, params: { id: huddle.id }
        expect(assigns(:existing_participant)).to eq(participant)
      end

      it 'renders the join template' do
        get :join, params: { id: huddle.id }
        expect(response).to render_template(:join)
      end
    end

    context 'when huddle does not exist' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect {
          get :join, params: { id: 99999 }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe 'POST #join_huddle' do
    let(:valid_params) do
      {
        id: huddle.id,
        name: 'John Doe',
        email: 'john@example.com',
        role: 'active'
      }
    end

    context 'with valid parameters' do
      it 'creates a new person if they do not exist' do
        expect {
          post :join_huddle, params: valid_params
        }.to change(Person, :count).by(1)
      end

      it 'creates a huddle participant' do
        expect {
          post :join_huddle, params: valid_params
        }.to change(HuddleParticipant, :count).by(1)
      end

      it 'sets the session with person id' do
        post :join_huddle, params: valid_params
        expect(session[:current_person_id]).to eq(Person.last.id)
      end

      it 'redirects to the huddle with success message' do
        post :join_huddle, params: valid_params
        expect(response).to redirect_to(huddle_path(huddle))
        expect(flash[:notice]).to eq('Welcome to the huddle!')
      end
    end

    context 'when user is already logged in' do
      let(:person) { Person.create!(full_name: 'Jane Smith', email: 'jane@example.com') }

      before do
        session[:current_person_id] = person.id
      end

      it 'does not create a new person' do
        expect {
          post :join_huddle, params: { id: huddle.id, role: 'observer' }
        }.not_to change(Person, :count)
      end

      it 'creates a huddle participant with the logged in person' do
        expect {
          post :join_huddle, params: { id: huddle.id, role: 'observer' }
        }.to change(HuddleParticipant, :count).by(1)
        
        participant = HuddleParticipant.last
        expect(participant.person).to eq(person)
        expect(participant.role).to eq('observer')
      end
    end

    context 'when user is already a participant' do
      let(:person) { Person.create!(full_name: 'Alice Johnson', email: 'alice@example.com') }
      let!(:participant) { huddle.huddle_participants.create!(person: person, role: 'active') }

      before do
        session[:current_person_id] = person.id
      end

      it 'updates the existing participant role' do
        post :join_huddle, params: { id: huddle.id, role: 'facilitator' }
        
        participant.reload
        expect(participant.role).to eq('facilitator')
      end

      it 'does not create a new participant' do
        expect {
          post :join_huddle, params: { id: huddle.id, role: 'facilitator' }
        }.not_to change(HuddleParticipant, :count)
      end
    end

    context 'with invalid parameters' do
      it 'renders the join template with errors' do
        post :join_huddle, params: { id: huddle.id, name: '', email: '', role: '' }
        expect(response).to render_template(:join)
      end
    end
  end

  describe 'GET #feedback' do
    context 'when user is not logged in' do
      it 'redirects to join page' do
        get :feedback, params: { id: huddle.id }
        expect(response).to redirect_to(join_huddle_path(huddle))
        expect(flash[:alert]).to eq('Please join the huddle before submitting feedback')
      end
    end

    context 'when user is logged in but not a participant' do
      let(:person) { Person.create!(full_name: 'John Doe', email: 'john@example.com') }

      before do
        session[:current_person_id] = person.id
      end

      it 'redirects to join page' do
        get :feedback, params: { id: huddle.id }
        expect(response).to redirect_to(join_huddle_path(huddle))
        expect(flash[:alert]).to eq('Please join the huddle before submitting feedback')
      end
    end

    context 'when user is a participant' do
      let(:person) { Person.create!(full_name: 'Jane Smith', email: 'jane@example.com') }
      let!(:participant) { huddle.huddle_participants.create!(person: person, role: 'active') }

      before do
        session[:current_person_id] = person.id
      end

      it 'assigns the huddle' do
        get :feedback, params: { id: huddle.id }
        expect(assigns(:huddle)).to eq(huddle)
      end

      it 'assigns the current person' do
        get :feedback, params: { id: huddle.id }
        expect(assigns(:current_person)).to eq(person)
      end

      it 'renders the feedback template' do
        get :feedback, params: { id: huddle.id }
        expect(response).to render_template(:feedback)
      end
    end
  end

  describe 'POST #submit_feedback' do
    let(:person) { Person.create!(full_name: 'John Doe', email: 'john@example.com') }
    let!(:participant) { huddle.huddle_participants.create!(person: person, role: 'active') }
    let(:valid_feedback_params) do
      {
        id: huddle.id,
        informed_rating: '4',
        connected_rating: '5',
        goals_rating: '4',
        valuable_rating: '5',
        appreciation: 'Great discussion',
        change_suggestion: 'More time for Q&A'
      }
    end

    before do
      session[:current_person_id] = person.id
    end

    context 'with valid parameters' do
      it 'creates a new huddle feedback' do
        expect {
          post :submit_feedback, params: valid_feedback_params
        }.to change(HuddleFeedback, :count).by(1)
      end

      it 'associates the feedback with the current person' do
        post :submit_feedback, params: valid_feedback_params
        
        feedback = HuddleFeedback.last
        expect(feedback.person).to eq(person)
        expect(feedback.huddle).to eq(huddle)
      end

      # Role is no longer updated in feedback form since we already know the user's role

      it 'redirects to huddle with success message' do
        post :submit_feedback, params: valid_feedback_params
        expect(response).to redirect_to(huddle_path(huddle))
        expect(flash[:notice]).to eq('Thank you for your feedback!')
      end
    end

    context 'with invalid parameters' do
      it 'renders the feedback template with errors' do
        post :submit_feedback, params: { id: huddle.id, informed_rating: '' }
        expect(response).to render_template(:feedback)
      end
    end

    context 'when user is not logged in' do
      before do
        session[:current_person_id] = nil
      end

      it 'redirects to join page' do
        post :submit_feedback, params: valid_feedback_params
        expect(response).to redirect_to(join_huddle_path(huddle))
        expect(flash[:alert]).to eq('Please join the huddle before submitting feedback')
      end
    end
  end
end 