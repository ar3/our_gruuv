require 'rails_helper'

RSpec.describe MaapSnapshot, type: :model do
  let(:organization) { create(:organization) }
  let(:employee) { create(:person) }
  let(:employee_teammate) { create(:teammate, person: employee, organization: organization) }
  let(:assignment1) { create(:assignment, company: organization, title: 'Employee Growth Plan Champion') }
  let(:assignment2) { create(:assignment, company: organization, title: 'Quarterly Conversation Coordinator') }

  before do
    # Set up employment tenure
    create(:employment_tenure, teammate: employee_teammate, company: organization)
    
    # Set up assignment tenures
    create(:assignment_tenure, teammate: employee_teammate, assignment: assignment1, anticipated_energy_percentage: 50)
    create(:assignment_tenure, teammate: employee_teammate, assignment: assignment2, anticipated_energy_percentage: 30)
    
    # Set up check-ins
    create(:assignment_check_in, teammate: employee_teammate, assignment: assignment1)
    create(:assignment_check_in, teammate: employee_teammate, assignment: assignment2)
  end

  describe 'build_official_check_in_data_with_changes' do
    context 'when check_in_id is nil and form params use assignment_id format' do
      it 'should not duplicate shared notes across assignments' do
        # Form params that match snapshot 106 scenario
        form_params = {
          "check_in_#{assignment1.id}_shared_notes" => 'Lifeline - working',
          "check_in_#{assignment2.id}_shared_notes" => 'emp grow - not set',
          "check_in_#{assignment1.id}_final_rating" => 'working_to_meet',
          "check_in_#{assignment2.id}_final_rating" => 'working_to_meet'
        }

        # Create MAAP snapshot
        snapshot = MaapSnapshot.build_for_employee_with_changes(
          employee: employee,
          created_by: employee,
          change_type: 'bulk_check_in_finalization',
          reason: 'Testing shared notes duplication',
          form_params: form_params
        )

        # Find assignments in the snapshot
        assignment1_data = snapshot.maap_data['assignments'].find { |a| a['id'] == assignment1.id }
        assignment2_data = snapshot.maap_data['assignments'].find { |a| a['id'] == assignment2.id }

        # Verify shared notes are correctly applied from form params

        # Verify form params are correctly applied to each assignment
        expect(assignment1_data['official_check_in']['shared_notes']).to eq('Lifeline - working')
        expect(assignment2_data['official_check_in']['shared_notes']).to eq('emp grow - not set')
        
        # Verify they are different
        expect(assignment1_data['official_check_in']['shared_notes']).not_to eq(assignment2_data['official_check_in']['shared_notes'])
      end
    end
  end
end
