require 'rails_helper'

RSpec.describe 'Organizations::Employees#index', type: :request do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  
  before do
    # Mock authentication
    allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(person)
    allow_any_instance_of(ApplicationController).to receive(:current_organization).and_return(organization)
    # Allow the method to be called with any organization type
    allow(person).to receive(:can_manage_employment?).and_return(true)
  end

  it 'renders without NoMethodError for unassigned employee uploads path' do
    expect {
      get organization_employees_path(organization)
    }.not_to raise_error
  end

  it 'renders the page successfully' do
    get organization_employees_path(organization)
    expect(response).to be_successful
  end

  it 'sets up all required instance variables' do
    get organization_employees_path(organization)
    expect(assigns(:organization)).to be_a(Organization)
    expect(assigns(:teammates)).to be_a(ActiveRecord::Relation)
    expect(assigns(:spotlight_stats)).to be_present
    expect(assigns(:current_filters)).to be_present
    expect(assigns(:current_sort)).to be_present
    expect(assigns(:current_view)).to be_present
    expect(assigns(:has_active_filters)).to be_present
  end
end
