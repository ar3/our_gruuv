require 'rails_helper'

RSpec.describe 'Organizations::Employees#index manager filter integration', type: :request do
  let(:organization) { create(:organization) }
  let(:manager) { create(:person) }
  let(:direct_report) { create(:person) }
  let(:non_direct_report) { create(:person) }
  
  let!(:manager_teammate) { create(:teammate, person: manager, organization: organization) }
  let!(:direct_report_teammate) { create(:teammate, person: direct_report, organization: organization) }
  let!(:non_direct_report_teammate) { create(:teammate, person: non_direct_report, organization: organization) }

  before do
    # Create employment tenures with manager relationships
    create(:employment_tenure, teammate: direct_report_teammate, company: organization, manager: manager, ended_at: nil)
    create(:employment_tenure, teammate: non_direct_report_teammate, company: organization, manager: nil, ended_at: nil)
    
    # Mock authentication for manager
    allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(manager)
  end

  it 'filters results when manager has direct reports' do
    # This test will fail if has_direct_reports? doesn't work correctly
    expect(manager.has_direct_reports?(organization)).to be true
    
    get organization_employees_path(organization, manager_filter: 'direct_reports')
    
    expect(response).to be_successful
    teammates = assigns(:teammates)
    
    # Should only include direct report, not non-direct report or manager
    expect(teammates).to include(direct_report_teammate)
    expect(teammates).not_to include(non_direct_report_teammate)
    expect(teammates).not_to include(manager_teammate)
  end

  it 'redirects when manager has no direct reports' do
    # Remove the direct report relationship
    EmploymentTenure.where(manager: manager).destroy_all
    
    expect(manager.has_direct_reports?(organization)).to be false
    
    get organization_employees_path(organization, manager_filter: 'direct_reports')
    
    expect(response).to be_redirect
    follow_redirect!
    expect(response.body).to include('You do not have any direct reports')
  end

  it 'renders check_in_status display without errors when manager filter is active' do
    get organization_employees_path(organization, manager_filter: 'direct_reports', display: 'check_in_status')
    
    expect(response).to be_successful
    expect(response.body).not_to include('Association named')
    expect(response.body).not_to include('assignment_check_ins')
  end
end
