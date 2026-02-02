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

end
