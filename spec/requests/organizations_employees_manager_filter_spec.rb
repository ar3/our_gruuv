require 'rails_helper'

RSpec.describe 'Organizations::Employees#index with manager filter', type: :request do
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
    
    # Set first_employed_at so teammates pass the 'active' status filter
    direct_report_teammate.update!(first_employed_at: 1.month.ago)
    non_direct_report_teammate.update!(first_employed_at: 1.month.ago)
    manager_teammate.update!(first_employed_at: 1.month.ago)
    
    # Mock authentication for manager
    allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(manager)
    allow(manager).to receive(:has_direct_reports?).and_return(true)
  end

  it 'returns only direct reports when manager_filter is direct_reports' do
    get organization_employees_path(organization, manager_filter: 'direct_reports')
    
    expect(response).to be_successful
    teammates = assigns(:teammates)
    
    # Should include direct report
    expect(teammates).to include(direct_report_teammate)
    # Should NOT include non-direct report
    expect(teammates).not_to include(non_direct_report_teammate)
    # Should NOT include manager
    expect(teammates).not_to include(manager_teammate)
  end

  it 'returns all teammates when manager_filter is not set' do
    get organization_employees_path(organization)
    
    expect(response).to be_successful
    teammates = assigns(:teammates)
    
    # Should include all teammates
    expect(teammates).to include(direct_report_teammate)
    expect(teammates).to include(non_direct_report_teammate)
    expect(teammates).to include(manager_teammate)
  end

  it 'renders the check_in_status display without errors' do
    get organization_employees_path(organization, manager_filter: 'direct_reports', display: 'check_in_status')
    
    expect(response).to be_successful
    expect(response.body).not_to include('Association named')
    expect(response.body).not_to include('assignment_check_ins')
  end
end
