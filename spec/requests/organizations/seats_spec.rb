require 'rails_helper'

RSpec.describe 'Organizations::Seats', type: :request do
  let(:person) { create(:person) }
  let(:company) { create(:organization, :company) }
  let(:person_teammate) { create(:teammate, person: person, organization: company, first_employed_at: 1.year.ago, can_manage_maap: true) }
  let(:position_major_level) { create(:position_major_level, major_level: 1, set_name: 'Engineering') }
  let(:position_type) { create(:position_type, organization: company, position_major_level: position_major_level) }
  let(:position_level) { create(:position_level, position_major_level: position_major_level, level: '1.1') }
  let(:position) { create(:position, position_type: position_type, position_level: position_level) }
  let(:seat) { create(:seat, position_type: position_type, seat_needed_by: Date.current) }

  before do
    # Ensure teammate has MAAP access
    person_teammate.update!(can_manage_maap: true)
    # Reload as CompanyTeammate to ensure methods are available
    person_ct = CompanyTeammate.find(person_teammate.id)
    
    # Mock authentication
    allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(person)
    allow_any_instance_of(ApplicationController).to receive(:current_company_teammate).and_return(person_ct)
    allow_any_instance_of(ApplicationController).to receive(:current_organization).and_return(company)
    # Set session for controller
    allow_any_instance_of(ApplicationController).to receive(:session).and_return({ current_company_teammate_id: person_teammate.id })
  end

  describe 'GET /organizations/:organization_id/seats/customize_view' do
    it 'returns http success' do
      get customize_view_organization_seats_path(company)
      expect(response).to have_http_status(:success)
    end

    it 'renders the customize view template' do
      get customize_view_organization_seats_path(company)
      expect(response).to render_template(:customize_view)
      expect(response).to render_template(layout: 'overlay')
    end

    it 'loads current filters and view state' do
      get customize_view_organization_seats_path(company, view: 'table_with_employee', state: ['open'])
      
      expect(response).to have_http_status(:success)
      # The view should render without syntax errors
      expect(response.body).to include('Customize Seats View')
      expect(response.body).to include('table_with_employee')
      expect(response.body).to include('open')
    end

    it 'sets return URL with current params' do
      get customize_view_organization_seats_path(company, view: 'table', state: ['filled'])
      
      expect(response).to have_http_status(:success)
      expect(response.body).to include(organization_seats_path(company))
    end

    it 'displays all view style options' do
      get customize_view_organization_seats_path(company)
      
      expect(response.body).to include('Table')
      expect(response.body).to include('Table with Employee')
      expect(response.body).to include('Seat - MAAP Health')
    end

    it 'displays all filter options' do
      get customize_view_organization_seats_path(company)
      
      expect(response.body).to include('Draft')
      expect(response.body).to include('Open')
      expect(response.body).to include('Filled')
      expect(response.body).to include('Archived')
      expect(response.body).to include('Has Direct Reports')
    end

    it 'displays preset options' do
      get customize_view_organization_seats_path(company)
      
      expect(response.body).to include('Seat hierarchy')
    end
  end

  describe 'PATCH /organizations/:organization_id/seats/update_view' do
    it 'redirects with view params' do
      patch update_view_organization_seats_path(company), params: {
        view: 'table_with_employee',
        state: ['open', 'filled']
      }
      
      expect(response).to have_http_status(:redirect)
      expect(response.location).to include(organization_seats_path(company).split('/').last)
      expect(response.location).to include('view=table_with_employee')
      expect(response.location).to include('state%5B%5D=open')
      expect(response.location).to include('state%5B%5D=filled')
    end

    it 'handles preset selection' do
      patch update_view_organization_seats_path(company), params: {
        preset: 'seat_hierarchy'
      }
      
      expect(response).to have_http_status(:redirect)
      expect(response.location).to include(organization_seats_path(company).split('/').last)
      expect(response.location).to include('view=seat_hierarchy')
    end

    it 'shows success notice' do
      patch update_view_organization_seats_path(company), params: {
        view: 'table'
      }
      
      expect(response).to have_http_status(:redirect)
      follow_redirect!
      expect(flash[:notice]).to eq('View updated successfully.')
    end
  end
end

