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

  describe 'check-in status display options' do
    context 'when user has manage_employment permission' do
      before do
        manager_teammate.update!(can_manage_employment: true)
        # Reload the teammate to ensure the flag is set
        manager_ct = CompanyTeammate.find(manager_teammate.id)
        allow_any_instance_of(ApplicationController).to receive(:current_company_teammate).and_return(manager_ct)
      end

      it 'shows Check-in Status Style 1 option as enabled' do
        get customize_view_organization_employees_path(organization)
        
        expect(response).to be_successful
        expect(response.body).to include('Check-in Status Style 1')
        expect(response.body).to include('id="view_check_in_status"')
        # Check that the radio button tag doesn't contain disabled attribute
        radio_button_match = response.body.match(/<input[^>]*id="view_check_in_status"[^>]*>/)
        expect(radio_button_match).to be_present
        expect(radio_button_match[0]).not_to include('disabled')
      end

      it 'shows Check-ins Health Style 2 option as enabled' do
        get customize_view_organization_employees_path(organization)
        
        expect(response).to be_successful
        expect(response.body).to include('Check-ins Health Style 2')
        expect(response.body).to include('id="view_check_ins_health"')
        # Check that the radio button tag doesn't contain disabled attribute
        radio_button_match = response.body.match(/<input[^>]*id="view_check_ins_health"[^>]*>/)
        expect(radio_button_match).to be_present
        expect(radio_button_match[0]).not_to include('disabled')
      end
    end

    context 'when user does not have manage_employment permission' do
      before do
        manager_teammate.update!(can_manage_employment: false)
        # Reload the teammate to ensure the flag is set
        manager_ct = CompanyTeammate.find(manager_teammate.id)
        allow_any_instance_of(ApplicationController).to receive(:current_company_teammate).and_return(manager_ct)
      end

      it 'shows Check-in Status Style 1 option as disabled with warning icon' do
        get customize_view_organization_employees_path(organization)
        
        expect(response).to be_successful
        expect(response.body).to include('Check-in Status Style 1')
        expect(response.body).to include('id="view_check_in_status"')
        expect(response.body).to include('disabled')
        expect(response.body).to include('bi-exclamation-triangle')
        expect(response.body).to include('You need employment management permission to use this option')
      end

      it 'shows Check-ins Health Style 2 option as disabled with warning icon' do
        get customize_view_organization_employees_path(organization)
        
        expect(response).to be_successful
        expect(response.body).to include('Check-ins Health Style 2')
        expect(response.body).to include('id="view_check_ins_health"')
        expect(response.body).to include('disabled')
        expect(response.body).to include('bi-exclamation-triangle')
        expect(response.body).to include('You need employment management permission to use this option')
      end
    end
  end

  describe 'check-ins health spotlight options' do
    context 'when user has manage_employment permission' do
      before do
        manager_teammate.update!(can_manage_employment: true)
        # Reload the teammate to ensure the flag is set
        manager_ct = CompanyTeammate.find(manager_teammate.id)
        allow_any_instance_of(ApplicationController).to receive(:current_company_teammate).and_return(manager_ct)
      end

      it 'shows Check-ins Health Style 1 spotlight option as enabled' do
        get customize_view_organization_employees_path(organization)
        
        expect(response).to be_successful
        expect(response.body).to include('Check-ins Health Style 1')
        expect(response.body).to include('id="spotlight_check_ins_health_style_1"')
        # Check that the radio button tag doesn't contain disabled attribute
        radio_button_match = response.body.match(/<input[^>]*id="spotlight_check_ins_health_style_1"[^>]*>/)
        expect(radio_button_match).to be_present
        expect(radio_button_match[0]).not_to include('disabled')
      end

      it 'shows Check-ins Health Style 2 spotlight option as enabled' do
        get customize_view_organization_employees_path(organization)
        
        expect(response).to be_successful
        expect(response.body).to include('Check-ins Health Style 2')
        expect(response.body).to include('id="spotlight_check_ins_health_style_2"')
        # Check that the radio button tag doesn't contain disabled attribute
        radio_button_match = response.body.match(/<input[^>]*id="spotlight_check_ins_health_style_2"[^>]*>/)
        expect(radio_button_match).to be_present
        expect(radio_button_match[0]).not_to include('disabled')
      end
    end

    context 'when user does not have manage_employment permission' do
      before do
        manager_teammate.update!(can_manage_employment: false)
        # Reload the teammate to ensure the flag is set
        manager_ct = CompanyTeammate.find(manager_teammate.id)
        allow_any_instance_of(ApplicationController).to receive(:current_company_teammate).and_return(manager_ct)
      end

      it 'shows Check-ins Health Style 1 spotlight option as disabled with warning icon' do
        get customize_view_organization_employees_path(organization)
        
        expect(response).to be_successful
        expect(response.body).to include('Check-ins Health Style 1')
        expect(response.body).to include('id="spotlight_check_ins_health_style_1"')
        expect(response.body).to include('disabled')
        expect(response.body).to include('bi-exclamation-triangle')
        expect(response.body).to include('You need employment management permission to use this option')
      end

      it 'shows Check-ins Health Style 2 spotlight option as disabled with warning icon' do
        get customize_view_organization_employees_path(organization)
        
        expect(response).to be_successful
        expect(response.body).to include('Check-ins Health Style 2')
        expect(response.body).to include('id="spotlight_check_ins_health_style_2"')
        expect(response.body).to include('disabled')
        expect(response.body).to include('bi-exclamation-triangle')
        expect(response.body).to include('You need employment management permission to use this option')
      end
    end
  end

  describe 'presets' do
    it 'does not include All Employees - Check-in Status Style 1 preset' do
      get customize_view_organization_employees_path(organization)
      
      expect(response).to be_successful
      expect(response.body).not_to include('All Employees - Check-in Status Style 1')
    end

    it 'does not include All Employees - Check-in Status Style 2 preset' do
      get customize_view_organization_employees_path(organization)
      
      expect(response).to be_successful
      expect(response.body).not_to include('All Employees - Check-in Status Style 2')
    end

    it 'still includes My Direct Reports presets' do
      get customize_view_organization_employees_path(organization)
      
      expect(response).to be_successful
      expect(response.body).to include('My Direct Reports - Check-in Status Style 1')
      expect(response.body).to include('My Direct Reports - Check-in Status Style 2')
    end
  end
end

