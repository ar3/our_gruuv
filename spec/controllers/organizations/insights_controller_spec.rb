require 'rails_helper'

RSpec.describe Organizations::InsightsController, type: :controller do
  let(:person) { create(:person) }
  let(:company) { create(:organization) }
  let(:person_teammate) { create(:teammate, person: person, organization: company, first_employed_at: 1.year.ago) }
  let(:department) { create(:department, company: company, name: 'Engineering') }
  let(:position_major_level) { create(:position_major_level, major_level: 1, set_name: 'Engineering') }
  let(:title) { create(:title, company: company, position_major_level: position_major_level, department: department) }
  let(:position_level) { create(:position_level, position_major_level: position_major_level, level: '1.1') }
  let(:position) { create(:position, title: title, position_level: position_level) }

  before do
    session[:current_company_teammate_id] = person_teammate.id
    @current_company_teammate = nil if defined?(@current_company_teammate)
  end

  describe 'GET #seats_titles_positions' do
    it 'returns http success' do
      get :seats_titles_positions, params: { organization_id: company.id }
      expect(response).to have_http_status(:success)
    end

    it 'calculates total seats' do
      # Ensure title exists
      title
      create(:seat, title: title, seat_needed_by: Date.current)
      create(:seat, title: title, seat_needed_by: Date.current + 1.month)
      
      get :seats_titles_positions, params: { organization_id: company.id }
      
      expect(assigns(:total_seats)).to eq(2)
    end

    it 'groups seats by state' do
      # Ensure title exists
      title
      create(:seat, :draft, title: title, seat_needed_by: Date.current)
      create(:seat, :open, title: title, seat_needed_by: Date.current + 1.month)
      create(:seat, :filled, title: title, seat_needed_by: Date.current + 2.months)
      
      get :seats_titles_positions, params: { organization_id: company.id }
      
      seats_by_state = assigns(:seats_by_state)
      expect(seats_by_state['draft']).to eq(1)
      expect(seats_by_state['open']).to eq(1)
      expect(seats_by_state['filled']).to eq(1)
    end

    it 'groups seats by department' do
      dept2 = create(:department, company: company, name: 'Product')
      title2 = create(:title, company: company, position_major_level: position_major_level, department: dept2, external_title: 'PM')
      
      # Ensure title exists
      title
      create(:seat, title: title, seat_needed_by: Date.current)
      create(:seat, title: title2, seat_needed_by: Date.current + 1.month)
      
      get :seats_titles_positions, params: { organization_id: company.id }
      
      seats_by_dept = assigns(:seats_by_department)
      expect(seats_by_dept['Engineering']).to eq(1)
      expect(seats_by_dept['Product']).to eq(1)
    end

    it 'counts seats without department' do
      title_no_dept = create(:title, company: company, position_major_level: position_major_level, department: nil, external_title: 'General')
      create(:seat, title: title_no_dept, seat_needed_by: Date.current)
      
      get :seats_titles_positions, params: { organization_id: company.id }
      
      expect(assigns(:seats_no_department)).to eq(1)
    end

    it 'calculates total titles' do
      # Ensure title exists first
      title
      create(:title, company: company, position_major_level: position_major_level, external_title: 'Title 2')
      
      get :seats_titles_positions, params: { organization_id: company.id }
      
      expect(assigns(:total_titles)).to eq(2)
    end

    it 'groups titles by department' do
      # Ensure title with department exists
      title
      
      get :seats_titles_positions, params: { organization_id: company.id }
      
      titles_by_dept = assigns(:titles_by_department)
      expect(titles_by_dept['Engineering']).to eq(1)
    end

    it 'counts titles without department' do
      title_no_dept = create(:title, company: company, position_major_level: position_major_level, department: nil, external_title: 'General')
      
      get :seats_titles_positions, params: { organization_id: company.id }
      
      expect(assigns(:titles_no_department)).to be >= 1
    end

    it 'calculates total positions' do
      # Ensure position exists first
      position
      position_level2 = create(:position_level, position_major_level: position_major_level, level: '1.2')
      create(:position, title: title, position_level: position_level2)
      
      get :seats_titles_positions, params: { organization_id: company.id }
      
      expect(assigns(:total_positions)).to eq(2)
    end

    it 'groups titles by position count' do
      # Title with 1 position
      position
      # Title with 0 positions
      title2 = create(:title, company: company, position_major_level: position_major_level, external_title: 'Title 2')
      
      get :seats_titles_positions, params: { organization_id: company.id }
      
      titles_by_pos_count = assigns(:titles_by_position_count)
      expect(titles_by_pos_count[1]).to eq(1) # title with position
      expect(titles_by_pos_count[0]).to eq(1) # title2 with no positions
    end

    it 'groups positions by required assignment count' do
      # Ensure position exists first
      position
      assignment = create(:assignment, company: company)
      create(:position_assignment, position: position, assignment: assignment, assignment_type: 'required')
      
      # Position with 1 required assignment
      get :seats_titles_positions, params: { organization_id: company.id }
      
      positions_by_assign_count = assigns(:positions_by_required_assignment_count)
      expect(positions_by_assign_count[1]).to eq(1)
    end

    context 'when teammate is not employed' do
      let(:unemployed_person) { create(:person) }
      let(:unemployed_teammate) { create(:teammate, person: unemployed_person, organization: company, first_employed_at: nil, last_terminated_at: nil) }

      before do
        # Create teammate without first_employed_at (not employed)
        session[:current_company_teammate_id] = unemployed_teammate.id
      end

      it 'denies access and redirects' do
        get :seats_titles_positions, params: { organization_id: company.id }
        
        expect(response).to have_http_status(:redirect)
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe 'GET #assignments' do
    it 'returns http success' do
      get :assignments, params: { organization_id: company.id }
      expect(response).to have_http_status(:success)
    end

    it 'calculates total assignments' do
      create(:assignment, company: company)
      create(:assignment, company: company)
      
      get :assignments, params: { organization_id: company.id }
      
      expect(assigns(:total_assignments)).to eq(2)
    end
  end

  describe 'GET #abilities' do
    it 'returns http success' do
      get :abilities, params: { organization_id: company.id }
      expect(response).to have_http_status(:success)
    end

    it 'calculates total abilities' do
      create(:ability, company: company, created_by: person, updated_by: person)
      create(:ability, company: company, created_by: person, updated_by: person)
      
      get :abilities, params: { organization_id: company.id }
      
      expect(assigns(:total_abilities)).to eq(2)
    end
  end

  describe 'GET #goals' do
    it 'returns http success' do
      get :goals, params: { organization_id: company.id }
      expect(response).to have_http_status(:success)
    end

    it 'calculates total goals' do
      create(:goal, owner: person_teammate, creator: person_teammate, company: company)
      create(:goal, owner: person_teammate, creator: person_teammate, company: company)
      
      get :goals, params: { organization_id: company.id }
      
      expect(assigns(:total_goals)).to eq(2)
    end
  end

  describe 'GET #observations' do
    it 'returns http success' do
      get :observations, params: { organization_id: company.id }
      expect(response).to have_http_status(:success)
    end

    it 'defaults timeframe to 90_days' do
      get :observations, params: { organization_id: company.id }
      expect(assigns(:timeframe)).to eq(:'90_days')
    end

    it 'accepts timeframe year' do
      get :observations, params: { organization_id: company.id, timeframe: 'year' }
      expect(assigns(:timeframe)).to eq(:year)
    end

    it 'accepts timeframe all_time' do
      get :observations, params: { organization_id: company.id, timeframe: 'all_time' }
      expect(assigns(:timeframe)).to eq(:all_time)
    end

    it 'assigns chart data with categories and series (90_days has ~13 weeks)' do
      get :observations, params: { organization_id: company.id }
      chart = assigns(:observations_chart_data)
      expect(chart).to be_a(Hash)
      expect(chart[:categories]).to be_an(Array)
      expect(chart[:series]).to be_an(Array)
      expect(chart[:categories].size).to be_between(12, 14)
      expect(chart[:series].map { |s| s[:name] }.sort).to eq(Observation.privacy_levels.keys.map { |k| k.to_s.humanize.titleize }.sort)
    end

    it 'assigns chart data with 52–53 week categories when timeframe is year' do
      get :observations, params: { organization_id: company.id, timeframe: 'year' }
      chart = assigns(:observations_chart_data)
      expect(chart[:categories].size).to be_between(52, 53)
    end

    it 'excludes observations outside range when timeframe is 90_days' do
      create(:observation, observer: person, company: company, published_at: 2.years.ago, observed_at: 2.years.ago, deleted_at: nil, observation_type: :kudos)
      get :observations, params: { organization_id: company.id, timeframe: '90_days' }
      teammates = assigns(:observer_teammates)
      expect(teammates.map(&:person_id)).not_to include(person.id)
      expect(assigns(:total_published_unarchived_by_observer)[person.id]).to be_nil
    end

    it 'lists observers as teammates who have given published observations' do
      obs = create(:observation, observer: person, company: company, published_at: 1.day.ago, deleted_at: nil, observation_type: :kudos)
      get :observations, params: { organization_id: company.id }
      teammates = assigns(:observer_teammates)
      expect(teammates.map(&:person_id)).to include(person.id)
      kudos = assigns(:kudos_feedback_mixed_by_observer)[person.id]
      expect(kudos[:kudos]).to eq(1)
      expect(kudos[:feedback]).to eq(0)
      expect(kudos[:mixed]).to eq(0)
    end

    it 'assigns privacy counts per observer' do
      create(:observation, observer: person, company: company, published_at: 1.day.ago, deleted_at: nil, privacy_level: :observer_only)
      create(:observation, observer: person, company: company, published_at: 1.day.ago, deleted_at: nil, privacy_level: :public_to_company)
      get :observations, params: { organization_id: company.id }
      counts = assigns(:privacy_counts_by_observer)[person.id]
      expect(counts['observer_only']).to eq(1)
      expect(counts['public_to_company']).to eq(1)
    end

    it 'excludes soft-deleted and draft observations' do
      create(:observation, observer: person, company: company, published_at: nil, deleted_at: nil)
      create(:observation, observer: person, company: company, published_at: 1.day.ago, deleted_at: 1.hour.ago)
      get :observations, params: { organization_id: company.id }
      teammates = assigns(:observer_teammates)
      expect(teammates.map(&:person_id)).not_to include(person.id)
    end
  end
end
