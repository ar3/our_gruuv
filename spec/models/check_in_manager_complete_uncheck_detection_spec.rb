require 'rails_helper'

RSpec.describe 'Check-In Manager Complete Uncheck Detection', type: :model do
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
  end

  describe 'manager complete uncheck change detection' do
    context 'when manager unchecks a previously completed check-in' do
      it 'should fail by not detecting the change from manager_complete true to false' do
        # Form params that represent unchecking the manager completion
        # The manager is now saying "don't mark this as manager complete"
        form_params = {
          "check_in_data" => {
            assignment.id.to_s => {
              "check_in_id" => @check_in.id,
              "manager_complete" => false,  # This is the key - setting to false means "don't mark as manager complete"
              "manager_rating" => "meeting",
              "shared_notes" => "Updated shared notes"
            }
          },
          "check_in_#{assignment.id}_manager_complete" => "false",
          "check_in_#{assignment.id}_manager_rating" => "meeting",
          "check_in_#{assignment.id}_shared_notes" => "Updated shared notes"
        }

        # Create a snapshot without maap_data
        snapshot = MaapSnapshot.build_for_employee_without_maap_data(
          employee: employee,
          created_by: manager,
          change_type: 'bulk_check_in_finalization',
          reason: 'Testing manager complete uncheck detection',
          form_params: form_params
        )

        # Process the snapshot with the processor
        snapshot.process_with_processor!

        # Find the assignment data in the processed snapshot
        assignment_data = snapshot.maap_data['assignments'].find { |a| a['id'] == assignment.id }
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
