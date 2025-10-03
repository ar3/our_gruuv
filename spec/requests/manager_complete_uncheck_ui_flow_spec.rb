require 'rails_helper'

RSpec.describe 'Manager Complete Uncheck UI Flow', type: :request do
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
    create(:teammate, person: manager, organization: organization, can_manage_employment: true)
    
    # Mock authentication
    allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(manager)
    allow_any_instance_of(ApplicationController).to receive(:authenticate_person!)
  end

  describe 'manager complete uncheck end-to-end flow' do
    context 'when manager unchecks a previously completed check-in via bulk finalization' do
      it 'should fail by not detecting the change from manager_complete true to false on execute changes page' do
        # Simulate the actual form submission that happens when manager unchecks manager_complete
        # This is what the UI actually sends when the manager unchecks the checkbox
        form_params = {
          "check_in_#{assignment.id}_manager_complete" => "false",  # This is the key - unchecking the checkbox
          "check_in_#{assignment.id}_manager_rating" => "meeting",
          "check_in_#{assignment.id}_shared_notes" => "Updated shared notes"
        }

        # Make the actual request to bulk_finalize_check_ins (this is what happens when manager submits)
        patch bulk_finalize_check_ins_organization_check_in_path(organization, employee), params: form_params

        # Should redirect to execute_changes page
        expect(response).to have_http_status(:redirect)
        redirect_location = response.location
        expect(redirect_location).to include("/organizations/#{organization.id}/people/#{employee.id}/execute_changes/")

        # Extract the maap_snapshot_id from the redirect
        maap_snapshot_id = redirect_location.match(/execute_changes\/(\d+)/)[1]
        maap_snapshot = MaapSnapshot.find(maap_snapshot_id)

        # Now visit the execute_changes page to see if the change is detected
        get execute_changes_organization_person_path(organization, employee, maap_snapshot)
        expect(response).to have_http_status(:success)

        # Find the assignment data in the processed snapshot
        assignment_data = maap_snapshot.maap_data['assignments'].find { |a| a['id'] == assignment.id }
        manager_check_in = assignment_data['manager_check_in']

        # Expected behavior: The change from manager complete to incomplete should be detected
        # The processor should include manager_check_in data even when manager_complete is false
        expect(manager_check_in).not_to be_nil, "Manager check-in data should be included even when manager_complete is false"
        
        # The manager_completed_at should be nil (not completed by manager)
        # The manager_completed_by_id should be nil (not completed by manager)
        expect(manager_check_in['manager_completed_at']).to be_nil
        expect(manager_check_in['manager_completed_by_id']).to be_nil
        
        # The other fields should still be updated
        expect(manager_check_in['manager_rating']).to eq('meeting')
        expect(manager_check_in['shared_notes']).to eq('Updated shared notes')
        
        # This spec now PASSES because the processor correctly handles manager_complete unchecking
        # It detects that the manager is changing from "manager complete" to "not manager complete"
      end
    end
  end
end
