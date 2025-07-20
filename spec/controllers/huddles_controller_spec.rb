require 'rails_helper'

RSpec.describe HuddlesController, type: :controller do
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

    context 'with duplicate huddle for same organization on same day' do
      let!(:company) { Company.create!(name: 'Acme Corp') }
      let!(:team) { Team.create!(name: 'Engineering', parent: company) }
      let!(:existing_person) { Person.create!(email: 'jane@example.com', full_name: 'Jane Doe', unique_textable_phone_number: '+12345678904') }
      let!(:existing_huddle) { Huddle.create!(organization: team, started_at: Time.current) }
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
end 