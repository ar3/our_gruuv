require 'rails_helper'

RSpec.describe MaapSnapshot, type: :model do
  let(:organization) { create(:organization) }
  let(:employee) { create(:person) }
  let(:employee_teammate) { create(:teammate, person: employee, organization: organization) }
  let(:assignment1) { create(:assignment, company: organization, title: 'Employee Growth Plan Champion', id: 80) }
  let(:assignment2) { create(:assignment, company: organization, title: 'Quarterly Conversation Coordinator', id: 81) }

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

  describe 'maap_data reflects DB state, form_params stored separately' do
    context 'when form params contain proposed changes' do
      it 'stores form_params separately and maap_data reflects DB state' do
        # Form params with proposed changes
        form_params = {
          "check_in_80_shared_notes" => 'Lifeline - working',
          "check_in_80_final_rating" => 'working_to_meet',
          "check_in_81_shared_notes" => 'emp grow - not set',
          "check_in_81_final_rating" => 'working_to_meet'
        }

        # Create MAAP snapshot
        snapshot = MaapSnapshot.build_for_employee_with_changes(
          employee: employee,
          created_by: employee,
          change_type: 'bulk_check_in_finalization',
          reason: 'Testing snapshot 106 exact duplication scenario',
          form_params: form_params
        )

        # Verify form_params are stored separately
        expect(snapshot.form_params).to eq(form_params)

        # Find assignments in the snapshot - maap_data should reflect DB state
        assignment1_data = snapshot.maap_data['assignments'].find { |a| a['assignment_id'] == assignment1.id }
        assignment2_data = snapshot.maap_data['assignments'].find { |a| a['assignment_id'] == assignment2.id }

        # maap_data should contain assignment_tenure data only (from DB)
        expect(assignment1_data).to be_present
        expect(assignment1_data['anticipated_energy_percentage']).to eq(50) # From DB
        expect(assignment1_data.keys).to match_array(%w[assignment_id anticipated_energy_percentage official_rating])
        
        expect(assignment2_data).to be_present
        expect(assignment2_data['anticipated_energy_percentage']).to eq(30) # From DB
        expect(assignment2_data.keys).to match_array(%w[assignment_id anticipated_energy_percentage official_rating])
        
        # maap_data should NOT contain check-in data (that's in form_params)
        expect(assignment1_data).not_to have_key('official_check_in')
        expect(assignment2_data).not_to have_key('official_check_in')
      end
    end
  end
end


