require 'rails_helper'

RSpec.describe 'Organizations::Employees#index with manager filter', type: :request do
  let(:organization) { create(:organization) }
  let(:manager) { create(:person) }
  let(:direct_report) { create(:person) }
  let(:non_direct_report) { create(:person) }
  
  let!(:manager_teammate) { create(:company_teammate, person: manager, organization: organization) }
  let!(:direct_report_teammate) { create(:company_teammate, person: direct_report, organization: organization) }
  let!(:non_direct_report_teammate) { create(:company_teammate, person: non_direct_report, organization: organization) }

  let(:manager_ct) { CompanyTeammate.find(manager_teammate.id) }
  let(:direct_report_ct) { CompanyTeammate.find(direct_report_teammate.id) }
  let(:non_direct_report_ct) { CompanyTeammate.find(non_direct_report_teammate.id) }

  before do
    # Set first_employed_at so teammates pass the 'active' status filter
    direct_report_teammate.update!(first_employed_at: 1.month.ago)
    non_direct_report_teammate.update!(first_employed_at: 1.month.ago)
    manager_teammate.update!(first_employed_at: 1.month.ago)
    
    # Create employment tenures with manager relationships
    create(:employment_tenure, teammate: direct_report_ct, company: organization, manager_teammate: manager_ct, ended_at: nil)
    create(:employment_tenure, teammate: non_direct_report_ct, company: organization, manager_teammate: nil, ended_at: nil)
    
    # Mock authentication for manager
    sign_in_as_teammate_for_request(manager, organization)
    allow_any_instance_of(ApplicationController).to receive(:current_company_teammate).and_return(manager_ct)
  end

  it 'returns only direct reports when manager_id is set' do
    get organization_employees_path(organization, manager_teammate_id: manager_ct.id)
    
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
    manager2_teammate = create(:company_teammate, person: manager2, organization: organization, first_employed_at: 1.month.ago)
    direct_report2 = create(:person)
    direct_report2_teammate = create(:company_teammate, person: direct_report2, organization: organization, first_employed_at: 1.month.ago)
    
    # Reload as CompanyTeammate instances
    manager2_ct = CompanyTeammate.find(manager2_teammate.id)
    direct_report2_ct = CompanyTeammate.find(direct_report2_teammate.id)
    create(:employment_tenure, teammate: direct_report2_ct, company: organization, manager_teammate: manager2_ct, ended_at: nil)
    
    get organization_employees_path(organization, manager_teammate_id: [manager_ct.id, manager2_ct.id])
    
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
    get organization_employees_path(organization, manager_teammate_id: manager_ct.id, display: 'check_in_status')
    
    expect(response).to be_successful
    expect(response.body).not_to include('Association named')
    expect(response.body).not_to include('assignment_check_ins')
  end
end
