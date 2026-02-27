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
    before do
      allow_any_instance_of(OrganizationPolicy).to receive(:view_goals?).and_return(true)
    end

    it 'returns http success' do
      get :goals, params: { organization_id: company.id }
      expect(response).to have_http_status(:success)
    end

    it 'assigns goals chart data' do
      create(:goal, owner: person_teammate, creator: person_teammate, company: company)
      create(:goal, owner: person_teammate, creator: person_teammate, company: company)
      
      get :goals, params: { organization_id: company.id }
      
      expect(assigns(:goals_chart_data)).to be_a(Hash)
      expect(assigns(:goals_chart_data)[:categories]).to be_an(Array)
    end

    it 'assigns goals_for_network_graph and goal_links_for_network_graph' do
      get :goals, params: { organization_id: company.id }
      expect(assigns(:goals_for_network_graph)).to be_an(Array)
      expect(assigns(:goal_links_for_network_graph)).to be_an(Array)
    end

    it 'includes active company-visible goals in network graph' do
      goal = create(:goal, :everyone_in_company, creator: person_teammate, owner: person_teammate, company: company, started_at: 1.week.ago, completed_at: nil)
      get :goals, params: { organization_id: company.id }
      expect(assigns(:goals_for_network_graph).map(&:id)).to include(goal.id)
    end

    it 'includes recently completed company-visible goals in network graph' do
      goal = create(:goal, :everyone_in_company, creator: person_teammate, owner: person_teammate, company: company, started_at: 2.months.ago, completed_at: 30.days.ago)
      get :goals, params: { organization_id: company.id }
      expect(assigns(:goals_for_network_graph).map(&:id)).to include(goal.id)
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

    it 'assigns chart data with 52–54 week categories when timeframe is year' do
      get :observations, params: { organization_id: company.id, timeframe: 'year' }
      chart = assigns(:observations_chart_data)
      expect(chart[:categories].size).to be_between(52, 54)
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

  describe 'GET #who_is_doing_what' do
    it 'returns http success' do
      get :who_is_doing_what, params: { organization_id: company.id }
      expect(response).to have_http_status(:success)
    end

    it 'assigns organization' do
      get :who_is_doing_what, params: { organization_id: company.id }
      expect(assigns(:organization)).to eq(company)
    end

    it 'assigns pie counts (with vs without page visit)' do
      get :who_is_doing_what, params: { organization_id: company.id }
      expect(assigns(:active_teammates_with_visit)).to be_a(Integer)
      expect(assigns(:active_teammates_without_visit)).to be_a(Integer)
    end

    it 'assigns top_pages as array of hashes with url, visit_count, page_title' do
      get :who_is_doing_what, params: { organization_id: company.id }
      expect(assigns(:top_pages)).to be_an(Array)
      assigns(:top_pages).each do |page|
        expect(page).to have_key(:url)
        expect(page).to have_key(:visit_count)
        expect(page).to have_key(:page_title)
      end
    end

    it 'assigns teammate_visit_counts with label and count' do
      get :who_is_doing_what, params: { organization_id: company.id }
      expect(assigns(:teammate_visit_counts)).to be_an(Array)
      assigns(:teammate_visit_counts).each do |row|
        expect(row).to have_key(:label)
        expect(row).to have_key(:count)
      end
    end

    it 'assigns period_stats with week, month, 90_days' do
      get :who_is_doing_what, params: { organization_id: company.id }
      expect(assigns(:period_stats)).to be_a(Hash)
      expect(assigns(:period_stats)).to have_key(:week)
      expect(assigns(:period_stats)).to have_key(:month)
      expect(assigns(:period_stats)).to have_key(:'90_days')
      assigns(:period_stats).each_value do |stats|
        expect(stats).to have_key(:unique_page_visits)
        expect(stats).to have_key(:unique_users)
      end
    end

    it 'counts teammate with page visit in pie' do
      create(:page_visit, person: person, url: '/org/dashboard', visit_count: 1, visited_at: 1.hour.ago)
      get :who_is_doing_what, params: { organization_id: company.id }
      expect(assigns(:active_teammates_with_visit)).to eq(1)
      expect(assigns(:active_teammates_without_visit)).to eq(0)
    end
  end

  describe 'GET #prompts' do
    before do
      allow_any_instance_of(OrganizationPolicy).to receive(:view_prompts?).and_return(true)
    end

    it 'returns http success' do
      get :prompts, params: { organization_id: company.id }
      expect(response).to have_http_status(:success)
    end

    it 'defaults timeframe to 90_days' do
      get :prompts, params: { organization_id: company.id }
      expect(assigns(:timeframe)).to eq(:'90_days')
    end

    it 'accepts timeframe year' do
      get :prompts, params: { organization_id: company.id, timeframe: 'year' }
      expect(assigns(:timeframe)).to eq(:year)
    end

    it 'accepts timeframe all_time' do
      get :prompts, params: { organization_id: company.id, timeframe: 'all_time' }
      expect(assigns(:timeframe)).to eq(:all_time)
    end

    it 'assigns organization' do
      get :prompts, params: { organization_id: company.id }
      expect(assigns(:organization)).to eq(company)
    end

    it 'assigns chart data with categories and series (90_days has ~13 weeks)' do
      get :prompts, params: { organization_id: company.id }
      chart = assigns(:prompts_answers_chart_data)
      expect(chart).to be_a(Hash)
      expect(chart[:categories]).to be_an(Array)
      expect(chart[:series]).to be_an(Array)
      expect(chart[:categories].size).to be_between(12, 14)
    end

    it 'assigns chart data with 52–54 week categories when timeframe is year' do
      get :prompts, params: { organization_id: company.id, timeframe: 'year' }
      chart = assigns(:prompts_answers_chart_data)
      expect(chart[:categories].size).to be_between(52, 54)
    end

    it 'includes prompt template names in series when prompts and answers exist' do
      template = create(:prompt_template, company: company, title: 'Growth Questions')
      question = create(:prompt_question, prompt_template: template, position: 1)
      prompt = create(:prompt, company_teammate: person_teammate, prompt_template: template, closed_at: nil)
      create(:prompt_answer, prompt: prompt, prompt_question: question, text: 'A substantial answer with more than ten characters.')
      get :prompts, params: { organization_id: company.id }
      chart = assigns(:prompts_answers_chart_data)
      expect(chart[:series].map { |s| s[:name] }).to include('Growth Questions')
    end

    it 'assigns teammates chart data with categories and series' do
      get :prompts, params: { organization_id: company.id }
      chart = assigns(:prompts_teammates_chart_data)
      expect(chart).to be_a(Hash)
      expect(chart[:categories]).to be_an(Array)
      expect(chart[:series]).to be_an(Array)
      expect(chart[:categories].size).to be_between(12, 14)
    end

    it 'teammates chart series are cumulative (count grows or stays same per template)' do
      template = create(:prompt_template, company: company, title: 'Growth')
      question = create(:prompt_question, prompt_template: template, position: 1)
      prompt = create(:prompt, company_teammate: person_teammate, prompt_template: template, closed_at: nil)
      create(:prompt_answer, prompt: prompt, prompt_question: question, text: 'Enough content here for the chart.')
      get :prompts, params: { organization_id: company.id }
      chart = assigns(:prompts_teammates_chart_data)
      growth_series = chart[:series].find { |s| s[:name] == 'Growth' }
      expect(growth_series).to be_present
      data = growth_series[:data]
      next_vals = data.each_cons(2).to_a
      next_vals.each { |a, b| expect(b).to be >= a }
    end

    it 'assigns prompts_download_teammate_count' do
      get :prompts, params: { organization_id: company.id }
      expect(assigns(:prompts_download_teammate_count)).to be_a(Integer)
      expect(assigns(:prompts_download_teammate_count)).to be >= 0
    end
  end

  describe 'GET #prompts_download' do
    before do
      allow_any_instance_of(OrganizationPolicy).to receive(:view_prompts?).and_return(true)
    end

    it 'returns http success and CSV with correct headers' do
      get :prompts_download, params: { organization_id: company.id }
      expect(response).to have_http_status(:success)
      expect(response.content_type).to include('text/csv')
      expect(response.body).to include('Teammate')
      expect(response.body).to include('Prompt template name')
      expect(response.body).to include('Date created')
    end

    it 'includes data row when open prompts exist' do
      template = create(:prompt_template, company: company, title: 'My Template')
      question = create(:prompt_question, prompt_template: template, position: 1, label: 'Q1')
      prompt = create(:prompt, company_teammate: person_teammate, prompt_template: template, closed_at: nil)
      create(:prompt_answer, prompt: prompt, prompt_question: question, text: 'My answer')
      get :prompts_download, params: { organization_id: company.id }
      expect(response.body).to include('My Template')
      expect(response.body).to include('My answer')
    end

    it 'sets Content-Disposition to attachment with filename' do
      get :prompts_download, params: { organization_id: company.id }
      expect(response.headers['Content-Disposition']).to match(/attachment.*active_prompts_.*\.csv/)
    end

    context 'when user has manage_employment' do
      before do
        allow_any_instance_of(OrganizationPolicy).to receive(:manage_employment?).and_return(true)
      end

      it 'includes prompts from all active teammates in organization' do
        other_teammate = create(:teammate, person: create(:person, first_name: 'Other', last_name: 'User'), organization: company, first_employed_at: 1.year.ago)
        template = create(:prompt_template, company: company, title: 'Shared Template')
        question = create(:prompt_question, prompt_template: template, position: 1)
        create(:prompt, company_teammate: person_teammate, prompt_template: template, closed_at: nil)
        other_prompt = create(:prompt, company_teammate: other_teammate, prompt_template: template, closed_at: nil)
        create(:prompt_answer, prompt: other_prompt, prompt_question: question, text: 'Other user answer')
        get :prompts_download, params: { organization_id: company.id }
        expect(response.body).to include('Other User')
        expect(response.body).to include('Other user answer')
      end
    end

    context 'when user lacks manage_employment and can_manage_prompts (self and reports only)' do
      before do
        allow_any_instance_of(OrganizationPolicy).to receive(:manage_employment?).and_return(false)
        allow_any_instance_of(CompanyTeammate).to receive(:can_manage_prompts?).and_return(false)
      end

      it 'includes only prompts for current user and reporting structure' do
        template = create(:prompt_template, company: company, title: 'My Template')
        question = create(:prompt_question, prompt_template: template, position: 1)
        my_prompt = create(:prompt, company_teammate: person_teammate, prompt_template: template, closed_at: nil)
        create(:prompt_answer, prompt: my_prompt, prompt_question: question, text: 'My own answer')
        other_teammate = create(:teammate, person: create(:person, first_name: 'Unrelated', last_name: 'Person'), organization: company, first_employed_at: 1.year.ago)
        other_prompt = create(:prompt, company_teammate: other_teammate, prompt_template: template, closed_at: nil)
        create(:prompt_answer, prompt: other_prompt, prompt_question: question, text: 'Unrelated answer')
        get :prompts_download, params: { organization_id: company.id }
        expect(response.body).to include('My own answer')
        expect(response.body).not_to include('Unrelated Person')
        expect(response.body).not_to include('Unrelated answer')
      end
    end
  end
end
