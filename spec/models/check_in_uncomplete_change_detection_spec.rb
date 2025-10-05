require 'rails_helper'

RSpec.describe 'Check-In Uncomplete Change Detection', type: :model do
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
           shared_notes: 'Previous shared notes',
           official_rating: 'meeting',
           official_check_in_completed_at: Time.current,
           finalized_by_id: manager.id)
  end

  describe 'uncomplete check-in change detection' do
    context 'when manager unchecks a previously completed check-in' do
      it 'should fail by not detecting the change from complete to incomplete' do
        # Form params that represent unchecking the completion
        # The manager is now saying "don't complete this check-in"
        form_params = {
          "check_in_data" => {
            assignment.id.to_s => {
              "check_in_id" => @check_in.id,
              "close_rating" => false,  # This is the key - setting to false means "don't complete"
              "final_rating" => "meeting",
              "shared_notes" => "Updated shared notes"
            }
          },
          "check_in_#{assignment.id}_close_rating" => "false",
          "check_in_#{assignment.id}_final_rating" => "meeting",
          "check_in_#{assignment.id}_shared_notes" => "Updated shared notes"
        }

        # Create a snapshot without maap_data
        snapshot = MaapSnapshot.build_for_employee_without_maap_data(
          employee: employee,
          created_by: manager,
          change_type: 'bulk_check_in_finalization',
          reason: 'Testing uncomplete change detection',
          form_params: form_params
        )

        # Process the snapshot with the processor
        snapshot.process_with_processor!

        # Find the assignment data in the processed snapshot
        assignment_data = snapshot.maap_data['assignments'].find { |a| a['id'] == assignment.id }
        official_check_in = assignment_data['official_check_in']

        # Expected behavior: The change from complete to incomplete should be detected
        # The processor should include official_check_in data even when close_rating is false
        expect(official_check_in).not_to be_nil, "Official check-in data should be included even when close_rating is false"
        
        # The official_check_in_completed_at should be nil (not completed)
        # The finalized_by_id should be nil (not finalized)
        expect(official_check_in['official_check_in_completed_at']).to be_nil
        expect(official_check_in['finalized_by_id']).to be_nil
        
        # The other fields should still be updated
        expect(official_check_in['official_rating']).to eq('meeting')
        expect(official_check_in['shared_notes']).to eq('Updated shared notes')
        
        # This spec now PASSES because the processor correctly handles uncompleting
        # It detects that the manager is changing from "complete" to "not complete"
      end
    end
  end
end
