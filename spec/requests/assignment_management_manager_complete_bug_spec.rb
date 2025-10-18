require 'rails_helper'

RSpec.describe 'Assignment Management Manager Complete Bug', type: :request do
  let(:organization) { create(:organization) }
  let(:manager) { create(:person) }
  let(:employee) { create(:person) }
  let(:manager_teammate) { create(:teammate, person: manager, organization: organization) }
  let(:employee_teammate) { create(:teammate, person: employee, organization: organization) }
  
  # Create assignments
  let(:assignment) { create(:assignment, company: organization, title: 'Test Assignment') }

  before do
    # Set up employment tenure
    create(:employment_tenure, teammate: manager_teammate, company: organization)
    create(:employment_tenure, teammate: employee_teammate, company: organization)
    
    # Set up assignment tenure
    create(:assignment_tenure, teammate: employee_teammate, assignment: assignment, anticipated_energy_percentage: 50)
    
    # Set up check-in that was previously completed by manager
    @check_in = create(:assignment_check_in, 
           teammate: employee_teammate, 
           assignment: assignment, 
           employee_completed_at: Time.current, 
           manager_completed_at: Time.current,
           manager_completed_by_id: manager.id,
           shared_notes: 'Previous shared notes',
           manager_rating: 'meeting')
    
    # Grant manager permissions
    manager_teammate.update!(can_manage_employment: true)
    
    # Mock authentication
    allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(manager)
    allow_any_instance_of(ApplicationController).to receive(:authenticate_person!)
  end

  describe 'assignment management manager complete bug' do
    context 'when manager sets manager_complete to "0" via assignment management but MAAP data still shows completed' do
      it 'should fail by reproducing the exact bug from assignment_management change type' do
        # Simulate the exact form submission from assignment management
        # The manager is explicitly setting manager_complete to "0" (false)
        form_params = {
          "check_in_#{assignment.id}_manager_complete" => "0",  # This is the key - explicitly set to "0"
          "tenure_#{assignment.id}_anticipated_energy" => "50"
        }

        # Make the actual request to assignment_tenures (assignment management)
        patch organization_person_check_ins_path(organization, employee), params: form_params

        # Should redirect to execute_changes page
        expect(response).to have_http_status(:redirect)
        redirect_location = response.location
        expect(redirect_location).to include("/organizations/#{organization.id}/people/#{employee.id}/execute_changes/")

        # Extract the maap_snapshot_id from the redirect
        maap_snapshot_id = redirect_location.match(/execute_changes\/(\d+)/)[1]
        maap_snapshot = MaapSnapshot.find(maap_snapshot_id)

        # Verify this is assignment_management change type
        expect(maap_snapshot.change_type).to eq('assignment_management')

        # Find the assignment data in the processed snapshot
        assignment_data = maap_snapshot.maap_data['assignments'].find { |a| a['id'] == assignment.id }
        manager_check_in = assignment_data['manager_check_in']

        # Debug output to see what's happening
        puts "\n=== ASSIGNMENT MANAGEMENT MANAGER COMPLETE BUG ==="
        puts "Assignment ID: #{assignment.id}"
        puts "Change type: #{maap_snapshot.change_type}"
        puts "Form params manager_complete: #{form_params["check_in_#{assignment.id}_manager_complete"]}"
        puts "Original manager_completed_at: #{@check_in.manager_completed_at}"
        puts "Processed manager_completed_at: #{manager_check_in['manager_completed_at']}"
        puts "Processed manager_completed_by_id: #{manager_check_in['manager_completed_by_id']}"
        puts "==================================================\n"

        # Expected behavior: When manager_complete is "0", the MAAP data should reflect this
        # The manager_completed_at should be nil (not completed by manager)
        # The manager_completed_by_id should be nil (not completed by manager)
        expect(manager_check_in['manager_completed_at']).to be_nil, 
          "BUG EXISTS: When manager_complete is '0' in assignment_management, manager_completed_at should be nil, but got: #{manager_check_in['manager_completed_at']}"
        expect(manager_check_in['manager_completed_by_id']).to be_nil,
          "BUG EXISTS: When manager_complete is '0' in assignment_management, manager_completed_by_id should be nil, but got: #{manager_check_in['manager_completed_by_id']}"
        
        # This spec should FAIL because the bug exists in assignment_management change type
        # The assignment_management processor is not properly handling manager_complete: "0"
      end
    end
  end
end


