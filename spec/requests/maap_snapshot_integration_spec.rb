require 'rails_helper'

RSpec.describe 'MaapSnapshot Integration', type: :request do
  before(:each) do
    # Clean up any existing data
    MaapSnapshot.destroy_all
    AssignmentCheckIn.destroy_all
    AssignmentTenure.destroy_all
  end
  
  let!(:organization) { create(:organization) }
  let!(:manager) { create(:person, current_organization: organization) }
  let!(:employee) { create(:person, current_organization: organization) }
  let!(:position_major_level) { create(:position_major_level) }
  let!(:position_level) { create(:position_level, position_major_level: position_major_level) }
  let!(:position_type) { create(:position_type, organization: organization, position_major_level: position_major_level) }
  let!(:position) { create(:position, position_type: position_type, position_level: position_level) }
  let!(:employment) { create(:employment_tenure, person: employee, position: position, company: organization) }
  let!(:assignment1) { create(:assignment, title: 'Assignment 1', company: organization) }
  
  before do
    # Set up position assignments
    create(:position_assignment, position: position, assignment: assignment1)
    
    # Set up employment for manager
    create(:employment_tenure, person: manager, position: position, company: organization)
    
    # Set up organization access for manager
    create(:person_organization_access, person: manager, organization: organization, can_manage_maap: true, can_manage_employment: true)
    
    # Set up initial data
    create(:assignment_tenure, person: employee, assignment: assignment1, anticipated_energy_percentage: 20)
    
    # Mock authentication
    allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(manager)
    allow_any_instance_of(ApplicationController).to receive(:authenticate_person!)
  end

  describe 'MaapSnapshot Creation' do
    it 'creates MaapSnapshot when form is submitted' do
      # Submit the form
      patch organization_assignment_tenure_path(organization, employee), params: { person_id: employee.id, reason: 'Test snapshot' }
      
      expect(response).to have_http_status(:redirect)
      
      # Verify MaapSnapshot was created
      expect(MaapSnapshot.count).to eq(1)
      maap_snapshot = MaapSnapshot.last
      expect(maap_snapshot.employee).to eq(employee)
      expect(maap_snapshot.created_by).to eq(manager)
      expect(maap_snapshot.company.id).to eq(organization.id)
      expect(maap_snapshot.change_type).to eq('assignment_management')
      expect(maap_snapshot.reason).to eq('Test snapshot')
      expect(maap_snapshot.pending?).to be true
      
      # Verify redirect to execute_changes
      expect(response).to redirect_to(execute_changes_organization_person_path(organization, employee, maap_snapshot))
    end

    it 'includes current MAAP data in snapshot' do
      patch organization_assignment_tenure_path(organization, employee), params: { person_id: employee.id }
      
      maap_snapshot = MaapSnapshot.last
      expect(maap_snapshot.maap_data['employment_tenure']).to be_present
      expect(maap_snapshot.maap_data['assignments']).to be_an(Array)
      expect(maap_snapshot.maap_data['assignments'].length).to eq(1)
      expect(maap_snapshot.maap_data['milestones']).to be_an(Array)
      expect(maap_snapshot.maap_data['aspirations']).to be_an(Array)
    end
  end

  describe 'MaapSnapshot Model Integration' do
    it 'builds complete MAAP data for employee' do
      maap_snapshot = MaapSnapshot.build_for_employee(
        employee: employee,
        created_by: manager,
        change_type: 'assignment_management',
        reason: 'Testing data building',
        request_info: { ip_address: '127.0.0.1' }
      )
      
      expect(maap_snapshot.maap_data['employment_tenure']).to include(
        'position_id' => employment.position_id,
        'manager_id' => employment.manager_id
      )
      expect(maap_snapshot.maap_data['employment_tenure']['started_at']).to be_present
      
      expect(maap_snapshot.maap_data['assignments']).to be_an(Array)
      expect(maap_snapshot.maap_data['assignments'].length).to eq(1)
      
      expect(maap_snapshot.maap_data['milestones']).to be_an(Array)
      expect(maap_snapshot.maap_data['aspirations']).to be_an(Array)
    end

    it 'creates exploration snapshots without employee' do
      maap_snapshot = MaapSnapshot.build_exploration(
        created_by: manager,
        company: organization,
        reason: 'Testing exploration',
        request_info: { ip_address: '127.0.0.1' }
      )
      
      expect(maap_snapshot.employee).to be_nil
      expect(maap_snapshot.created_by).to eq(manager)
      expect(maap_snapshot.company).to eq(organization)
      expect(maap_snapshot.change_type).to eq('exploration')
      expect(maap_snapshot.exploration_snapshot?).to be true
    end
  end

  describe 'MaapSnapshot Execution' do
    let!(:maap_snapshot) do
      create(:maap_snapshot, 
        employee: employee, 
        created_by: manager, 
        company: organization,
        change_type: 'assignment_management',
        reason: 'Test execution',
        maap_data: {
          employment_tenure: {
            position_id: position.id,
            manager_id: manager.id,
            started_at: employment.started_at,
            seat_id: nil
          },
          assignments: [
            {
              id: assignment1.id,
              tenure: {
                anticipated_energy_percentage: 35,
                started_at: Date.current
              },
              employee_check_in: nil,
              manager_check_in: nil,
              official_check_in: nil
            }
          ],
          milestones: [],
          aspirations: []
        }
      )
    end

    it 'executes changes successfully' do
      # Test the execution logic directly
      expect {
        maap_snapshot.update!(effective_date: Date.current)
      }.to change { maap_snapshot.reload.effective_date }.from(nil).to(Date.current)
      
      # Verify MaapSnapshot was executed
      expect(maap_snapshot.executed?).to be true
    end
  end
end