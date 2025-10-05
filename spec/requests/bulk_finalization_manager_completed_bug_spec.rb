require 'rails_helper'

RSpec.describe 'Bulk Finalization Manager Completed Bug', type: :request do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:manager) { create(:person) }
  let(:person_teammate) { create(:teammate, person: person, organization: organization) }
  let(:manager_teammate) { create(:teammate, person: manager, organization: organization) }
  let(:assignment1) { create(:assignment, company: organization) }
  let(:assignment2) { create(:assignment, company: organization) }

  before do
    create(:employment_tenure, teammate: manager_teammate, company: organization)
    create(:employment_tenure, teammate: person_teammate, company: organization)
    manager_teammate.update!(can_manage_employment: true, can_manage_maap: true)

    # Create assignment tenures so the processor can find the assignments
    create(:assignment_tenure, teammate: person_teammate, assignment: assignment1, anticipated_energy_percentage: 50)
    create(:assignment_tenure, teammate: person_teammate, assignment: assignment2, anticipated_energy_percentage: 75)
  end

  describe 'bulk finalization should not unset manager_completed fields' do
    before do
      # Create check-ins that are ready for finalization (both employee and manager completed)
      @check_in1 = create(:assignment_check_in,
                          teammate: person_teammate,
                          assignment: assignment1,
                          employee_completed_at: Time.current,
                          manager_completed_at: Time.current,
                          manager_completed_by_id: manager.id,
                          manager_rating: 'meeting',
                          manager_private_notes: 'Good work on assignment 1')

      @check_in2 = create(:assignment_check_in,
                          teammate: person_teammate,
                          assignment: assignment2,
                          employee_completed_at: Time.current,
                          manager_completed_at: Time.current,
                          manager_completed_by_id: manager.id,
                          manager_rating: 'exceeding',
                          manager_private_notes: 'Excellent work on assignment 2')

      # Mock authentication
      allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(manager)
      allow_any_instance_of(ApplicationController).to receive(:authenticate_person!)
    end

    it 'should preserve manager_completed fields when executing bulk finalization' do
      # Simulate bulk finalization form submission
      bulk_finalize_params = {
        "check_in_#{@check_in1.id}_final_rating" => 'meeting',
        "check_in_#{@check_in1.id}_shared_notes" => 'Final notes for assignment 1',
        "check_in_#{@check_in2.id}_final_rating" => 'exceeding',
        "check_in_#{@check_in2.id}_shared_notes" => 'Final notes for assignment 2'
      }

      # Step 1: Create the bulk finalization snapshot
      patch bulk_finalize_check_ins_organization_check_in_path(organization, person), params: bulk_finalize_params
      expect(response).to have_http_status(:redirect)

      # Find the created snapshot
      snapshot = MaapSnapshot.last
      expect(snapshot.change_type).to eq('bulk_check_in_finalization')
      

      # Step 2: Execute the changes
      post process_changes_organization_person_path(organization, person, snapshot)
      expect(response).to have_http_status(:redirect)

      # Step 3: Verify that manager_completed fields are preserved
      @check_in1.reload
      @check_in2.reload

      # These should NOT be nil - the bug is that they become nil
      expect(@check_in1.manager_completed_at).not_to be_nil,
        "Expected manager_completed_at to be preserved for check_in1, but it was nil"
      expect(@check_in1.manager_completed_by).not_to be_nil,
        "Expected manager_completed_by to be preserved for check_in1, but it was nil"
      expect(@check_in1.manager_rating).to eq('meeting')
      expect(@check_in1.manager_private_notes).to eq('Good work on assignment 1')

      expect(@check_in2.manager_completed_at).not_to be_nil,
        "Expected manager_completed_at to be preserved for check_in2, but it was nil"
      expect(@check_in2.manager_completed_by).not_to be_nil,
        "Expected manager_completed_by to be preserved for check_in2, but it was nil"
      expect(@check_in2.manager_rating).to eq('exceeding')
      expect(@check_in2.manager_private_notes).to eq('Excellent work on assignment 2')

      # Verify that official finalization fields are set correctly
      expect(@check_in1.official_check_in_completed_at).not_to be_nil
      expect(@check_in1.finalized_by).to eq(manager)
      expect(@check_in1.shared_notes).to eq('Final notes for assignment 1')

      expect(@check_in2.official_check_in_completed_at).not_to be_nil
      expect(@check_in2.finalized_by).to eq(manager)
      expect(@check_in2.shared_notes).to eq('Final notes for assignment 2')
    end

    it 'should show correct changes on execute_changes page' do
      # Create the bulk finalization snapshot
      bulk_finalize_params = {
        "check_in_#{@check_in1.id}_final_rating" => 'meeting',
        "check_in_#{@check_in1.id}_shared_notes" => 'Final notes for assignment 1',
        "check_in_#{@check_in2.id}_final_rating" => 'exceeding',
        "check_in_#{@check_in2.id}_shared_notes" => 'Final notes for assignment 2'
      }

      patch bulk_finalize_check_ins_organization_check_in_path(organization, person), params: bulk_finalize_params
      snapshot = MaapSnapshot.last

      # Check the execute_changes page
      get execute_changes_organization_person_path(organization, person, snapshot)
      expect(response).to have_http_status(:success)

      # The page should NOT show manager completion as being unset
      # This is the bug - it incorrectly shows manager completion being changed to nil
      # Since we fixed the bug, manager completion should not appear as a change
      # Note: The comment "<!-- Manager Completion Field -->" is expected, but the actual content should not render
      # Note: "CHANGED" badges for official completion are expected and correct
      expect(response.body).not_to include('<strong>Manager Completion</strong>')
      
      # Verify that manager completion is not being shown as changed
      # Look for the specific pattern that would indicate manager completion being unset
      # Note: We need to be more specific since the comment contains "Manager Completion"
      expect(response.body).not_to include('Manager Completion</strong>')
      
      # But official completion changes should be present (this is the intended behavior)
      expect(response.body).to include('Official Completion')
      expect(response.body).to include('CHANGED')
      
      # The key test: manager completion should not be shown as a change
      # We can verify this by checking that the manager completion partial content is not rendered
      expect(response.body).not_to include('bg-warning me-2">CHANGED</span>')
      expect(response.body).not_to include('text-muted">Completed</span>')
      expect(response.body).not_to include('text-muted">Not completed</span>')
    end
  end
end
