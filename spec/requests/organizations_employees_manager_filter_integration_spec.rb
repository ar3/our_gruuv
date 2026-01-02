require 'rails_helper'

RSpec.describe 'Organizations::Employees#index manager filter integration', type: :request do
  let(:organization) { create(:organization) }
  let(:manager) { create(:person) }
  let(:direct_report) { create(:person) }
  let(:non_direct_report) { create(:person) }
  
  let!(:manager_teammate) { create(:teammate, type: 'CompanyTeammate', person: manager, organization: organization) }
  let!(:direct_report_teammate) { create(:teammate, person: direct_report, organization: organization) }
  let!(:non_direct_report_teammate) { create(:teammate, person: non_direct_report, organization: organization) }

  before do
    # Create employment tenures with manager relationships
    create(:employment_tenure, teammate: direct_report_teammate, company: organization, manager_teammate: manager_teammate, ended_at: nil)
    create(:employment_tenure, teammate: non_direct_report_teammate, company: organization, manager_teammate: nil, ended_at: nil)
    
    # Set first_employed_at so teammates pass the 'active' status filter
    direct_report_teammate.update!(first_employed_at: 1.month.ago)
    non_direct_report_teammate.update!(first_employed_at: 1.month.ago)
    manager_teammate.update!(first_employed_at: 1.month.ago)
    
    # Reload as CompanyTeammate to ensure has_direct_reports? method is available
    manager_ct = CompanyTeammate.find(manager_teammate.id)
    
    # Mock authentication for manager
    sign_in_as_teammate_for_request(manager, organization)
    allow_any_instance_of(ApplicationController).to receive(:current_company_teammate).and_return(manager_ct)
  end

  it 'filters results when manager has direct reports' do
    # This test will fail if has_direct_reports? doesn't work correctly
    # Reload to get CompanyTeammate instance
    manager_ct = CompanyTeammate.find(manager_teammate.id)
    expect(manager_ct.has_direct_reports?).to be true
    
    get organization_employees_path(organization, manager_teammate_id: manager_teammate.id)
    
    expect(response).to be_successful
    teammates = assigns(:filtered_and_paginated_teammates)
    
    # Should only include direct report, not non-direct report or manager
    expect(teammates.map(&:id)).to include(direct_report_teammate.id)
    expect(teammates.map(&:id)).not_to include(non_direct_report_teammate.id)
    expect(teammates.map(&:id)).not_to include(manager_teammate.id)
  end

  it 'returns empty results when manager has no direct reports' do
    # Remove the direct report relationship
    EmploymentTenure.where(manager_teammate: manager_teammate).destroy_all
    
    # Reload to get CompanyTeammate instance
    manager_ct = CompanyTeammate.find(manager_teammate.id)
    expect(manager_ct.has_direct_reports?).to be false
    
    get organization_employees_path(organization, manager_teammate_id: manager_teammate.id)
    
    expect(response).to be_successful
    teammates = assigns(:filtered_and_paginated_teammates)
    expect(teammates).to be_empty
  end

  it 'renders check_in_status display without errors when manager filter is active' do
    get organization_employees_path(organization, manager_id: manager.id, display: 'check_in_status')
    
    expect(response).to be_successful
    expect(response.body).not_to include('Association named')
    expect(response.body).not_to include('assignment_check_ins')
  end
end
