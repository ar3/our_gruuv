require 'rails_helper'

RSpec.describe 'Snapshot 119 Manager Complete Bug Reproduction', type: :request do
  let(:organization) { create(:organization) }
  let(:manager) { create(:person) }
  let(:employee) { create(:person) }
  
  # Create assignments
  let(:assignment) { create(:assignment, company: organization, title: 'Test Assignment') }

  before do
    # Set up employment tenure
    create(:employment_tenure, person: manager, company: organization)
    create(:employment_tenure, person: employee, company: organization)
    
    # Set up assignment tenure
    create(:assignment_tenure, person: employee, assignment: assignment, anticipated_energy_percentage: 50)
    
    # Set up check-in that was previously completed by manager
    @check_in = create(:assignment_check_in, 
           person: employee, 
           assignment: assignment, 
           employee_completed_at: Time.current, 
           manager_completed_at: Time.current,
           manager_completed_by_id: manager.id,
           shared_notes: 'Previous shared notes',
           manager_rating: 'meeting')
    
    # Grant manager permissions
    create(:person_organization_access, person: manager, organization: organization, can_manage_employment: true)
    
    # Mock authentication
    allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(manager)
    allow_any_instance_of(ApplicationController).to receive(:authenticate_person!)
  end

  describe 'snapshot 119 manager complete bug reproduction' do
    context 'when manager sets manager_complete to "0" but MAAP data still shows completed' do
      it 'should fail by reproducing the exact bug from snapshot 119' do
        # Simulate the exact form submission from snapshot 119
        # The manager is explicitly setting manager_complete to "0" (false)
        form_params = {
          "check_in_#{assignment.id}_manager_complete" => "0",  # This is the key - explicitly set to "0"
          "check_in_#{assignment.id}_manager_rating" => "meeting",
          "check_in_#{assignment.id}_shared_notes" => "Updated shared notes"
        }

        # Make the actual request to bulk_finalize_check_ins
        patch bulk_finalize_check_ins_organization_check_in_path(organization, employee), params: form_params

        # Should redirect to execute_changes page
        expect(response).to have_http_status(:redirect)
        redirect_location = response.location
        expect(redirect_location).to include("/organizations/#{organization.id}/people/#{employee.id}/execute_changes/")

        # Extract the maap_snapshot_id from the redirect
        maap_snapshot_id = redirect_location.match(/execute_changes\/(\d+)/)[1]
        maap_snapshot = MaapSnapshot.find(maap_snapshot_id)

        # Find the assignment data in the processed snapshot
        assignment_data = maap_snapshot.maap_data['assignments'].find { |a| a['id'] == assignment.id }
        manager_check_in = assignment_data['manager_check_in']

        # Debug output to see what's happening
        puts "\n=== SNAPSHOT 119 BUG REPRODUCTION ==="
        puts "Assignment ID: #{assignment.id}"
        puts "Form params manager_complete: #{form_params["check_in_#{assignment.id}_manager_complete"]}"
        puts "Original manager_completed_at: #{@check_in.manager_completed_at}"
        puts "Processed manager_completed_at: #{manager_check_in['manager_completed_at']}"
        puts "Processed manager_completed_by_id: #{manager_check_in['manager_completed_by_id']}"
        puts "=====================================\n"

        # Expected behavior: When manager_complete is "0", the MAAP data should reflect this
        # The manager_completed_at should be nil (not completed by manager)
        # The manager_completed_by_id should be nil (not completed by manager)
        expect(manager_check_in['manager_completed_at']).to be_nil, 
          "When manager_complete is '0', manager_completed_at should be nil, but got: #{manager_check_in['manager_completed_at']}"
        expect(manager_check_in['manager_completed_by_id']).to be_nil,
          "When manager_complete is '0', manager_completed_by_id should be nil, but got: #{manager_check_in['manager_completed_by_id']}"
        
        # The other fields should still be updated
        expect(manager_check_in['manager_rating']).to eq('meeting')
        expect(manager_check_in['shared_notes']).to eq('Updated shared notes')
        
        # This spec now PASSES because the processor correctly handles manager_complete: "0"
        # It detects that the manager is explicitly setting completion to false
      end
    end
  end
end
