require 'rails_helper'

RSpec.describe 'Organizations::Employees#customize_view', type: :request do
  let(:organization) { create(:organization) }
  let(:manager) { create(:person) }
  let(:direct_report) { create(:person) }
  let!(:manager_teammate) { create(:teammate, type: 'CompanyTeammate', person: manager, organization: organization) }
  let(:direct_report_teammate) { create(:teammate, person: direct_report, organization: organization) }

  before do
    # Create employment tenure with manager relationship
    create(:employment_tenure, teammate: direct_report_teammate, company: organization, manager: manager, ended_at: nil)
    
    # Reload as CompanyTeammate to ensure has_direct_reports? method is available
    manager_ct = CompanyTeammate.find(manager_teammate.id)
    
    # Mock authentication for manager
    allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(manager)
    allow_any_instance_of(ApplicationController).to receive(:current_company_teammate).and_return(manager_ct)
    allow_any_instance_of(ApplicationController).to receive(:current_organization).and_return(organization)
  end

  it 'renders without NoMethodError when accessing customize_view' do
    expect {
      get customize_view_organization_employees_path(organization)
    }.not_to raise_error
  end

  it 'renders the customize_view page successfully' do
    get customize_view_organization_employees_path(organization)
    expect(response).to be_successful
  end

  it 'uses teammate instead of person for has_direct_reports? check' do
    # This test will fail if the bug exists (calling has_direct_reports? on Person)
    # and pass once we fix it (calling has_direct_reports? on CompanyTeammate)
    get customize_view_organization_employees_path(organization)
    
    expect(response).to be_successful
    # If we get here without a NoMethodError, the bug is fixed
    expect(response.body).to be_present
  end

  it 'renders manager checkboxes' do
    get customize_view_organization_employees_path(organization)
    
    expect(response).to be_successful
    expect(response.body).to include('manager_id[]')
    expect(response.body).to include('form-check-input')
  end

  it 'renders department checkboxes when departments exist' do
    department = create(:organization, type: 'Department', parent: organization)
    
    get customize_view_organization_employees_path(organization)
    
    expect(response).to be_successful
    expect(response.body).to include('department_id[]')
    expect(response.body).to include('form-check-input')
    expect(response.body).to include(department.name)
  end

  it 'shows message when no departments exist' do
    get customize_view_organization_employees_path(organization)
    
    expect(response).to be_successful
    # Should show message if no departments
    if assigns(:active_departments).empty?
      expect(response.body).to include('No departments available')
    end
  end

  it 'preserves selected manager filters' do
    get customize_view_organization_employees_path(organization, manager_id: manager.id)
    
    expect(response).to be_successful
    expect(assigns(:current_filters)[:manager_id]).to include(manager.id.to_s)
  end

  it 'preserves selected department filters' do
    department = create(:organization, type: 'Department', parent: organization)
    
    get customize_view_organization_employees_path(organization, department_id: department.id)
    
    expect(response).to be_successful
    expect(assigns(:current_filters)[:department_id]).to include(department.id.to_s)
  end
end

