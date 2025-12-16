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
    
    # Reload as CompanyTeammate to ensure has_direct_reports? method is available
    manager_ct = CompanyTeammate.find(manager_teammate.id)
    
    # Mock authentication for manager
    sign_in_as_teammate_for_request(manager, organization)
    allow_any_instance_of(ApplicationController).to receive(:current_company_teammate).and_return(manager_ct)
  end

  it 'returns only direct reports when manager_id is set' do
    get organization_employees_path(organization, manager_id: manager.id)
    
    expect(response).to be_successful
    teammates = assigns(:filtered_and_paginated_teammates)
    
    # Should include direct report
    expect(teammates.map(&:id)).to include(direct_report_teammate.id)
    # Should NOT include non-direct report
    expect(teammates.map(&:id)).not_to include(non_direct_report_teammate.id)
    # Should NOT include manager
    expect(teammates.map(&:id)).not_to include(manager_teammate.id)
  end

  it 'returns direct reports for multiple managers when manager_id[] is set' do
    manager2 = create(:person)
    manager2_teammate = create(:teammate, person: manager2, organization: organization, first_employed_at: 1.month.ago)
    direct_report2 = create(:person)
    direct_report2_teammate = create(:teammate, person: direct_report2, organization: organization, first_employed_at: 1.month.ago)
    create(:employment_tenure, teammate: direct_report2_teammate, company: organization, manager: manager2, ended_at: nil)
    
    get organization_employees_path(organization, manager_id: [manager.id, manager2.id])
    
    expect(response).to be_successful
    teammates = assigns(:filtered_and_paginated_teammates)
    
    # Should include direct reports from both managers
    expect(teammates.map(&:id)).to include(direct_report_teammate.id)
    expect(teammates.map(&:id)).to include(direct_report2_teammate.id)
    # Should NOT include non-direct report
    expect(teammates.map(&:id)).not_to include(non_direct_report_teammate.id)
    # Should NOT include managers
    expect(teammates.map(&:id)).not_to include(manager_teammate.id)
  end

  it 'returns all teammates when manager_id is not set' do
    get organization_employees_path(organization)
    
    expect(response).to be_successful
    teammates = assigns(:filtered_and_paginated_teammates)
    
    # Should include all teammates
    expect(teammates.map(&:id)).to include(direct_report_teammate.id)
    expect(teammates.map(&:id)).to include(non_direct_report_teammate.id)
    expect(teammates.map(&:id)).to include(manager_teammate.id)
  end

  it 'renders the check_in_status display without errors' do
    get organization_employees_path(organization, manager_id: manager.id, display: 'check_in_status')
    
    expect(response).to be_successful
    expect(response.body).not_to include('Association named')
    expect(response.body).not_to include('assignment_check_ins')
  end
end
