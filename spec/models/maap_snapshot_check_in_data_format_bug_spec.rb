require 'rails_helper'

RSpec.describe 'MaapSnapshot CheckInData Format Bug', type: :model do
  let(:organization) { create(:organization) }
  let(:employee) { create(:person) }
  let(:employee_teammate) { create(:company_teammate, person: employee, organization: organization) }
  
  # Create assignments with the exact IDs from snapshot 110
  let(:emp_growth_assignment) { create(:assignment, company: organization, title: 'Employee Growth Plan Champion', id: 80) }
  let(:quarterly_assignment) { create(:assignment, company: organization, title: 'Quarterly Conversation Coordinator', id: 81) }
  let(:lifeline_assignment) { create(:assignment, company: organization, title: 'Lifeline Interview Facilitator', id: 84) }

  before do
    # Set up employment tenure
    create(:employment_tenure, teammate: employee_teammate, company: organization)
    
    # Set up assignment tenures
    create(:assignment_tenure, teammate: employee_teammate, assignment: emp_growth_assignment, anticipated_energy_percentage: 50)
    create(:assignment_tenure, teammate: employee_teammate, assignment: quarterly_assignment, anticipated_energy_percentage: 30)
    create(:assignment_tenure, teammate: employee_teammate, assignment: lifeline_assignment, anticipated_energy_percentage: 20)
    
    # Set up check-ins with existing data (ready for finalization)
    manager_teammate = create(:company_teammate, organization: organization, can_manage_employment: true)
    
    @emp_growth_check_in = create(:assignment_check_in, 
           teammate: employee_teammate, 
           assignment: emp_growth_assignment, 
           employee_completed_at: Time.current, 
           manager_completed_at: Time.current,
           manager_completed_by_teammate: manager_teammate,
           shared_notes: 'Existing emp growth notes',
           official_rating: 'exceeding')
           
    @quarterly_check_in = create(:assignment_check_in, 
           teammate: employee_teammate, 
           assignment: quarterly_assignment, 
           employee_completed_at: Time.current, 
           manager_completed_at: Time.current,
           manager_completed_by_teammate: manager_teammate,
           shared_notes: 'Existing quarterly notes',
           official_rating: 'exceeding')
           
    @lifeline_check_in = create(:assignment_check_in, 
           teammate: employee_teammate, 
           assignment: lifeline_assignment, 
           employee_completed_at: Time.current, 
           manager_completed_at: Time.current,
           manager_completed_by_teammate: manager_teammate,
           shared_notes: 'Existing lifeline notes',
           official_rating: 'exceeding')
  end

  describe 'maap_data reflects DB state, form_params stored separately' do
    context 'when form_params contains check_in_data hash format' do
      it 'stores form_params separately and maap_data reflects DB state' do
        # Form params that use the check_in_data hash format (like snapshot 110)
        form_params = {
          "check_in_data" => {
            "80" => {
              "check_in_id" => @emp_growth_check_in.id,
              "close_rating" => false,
              "final_rating" => "working_to_meet",
              "shared_notes" => "Lifeline - work - incomplete"
            },
            "81" => {
              "check_in_id" => @quarterly_check_in.id,
              "close_rating" => false,
              "final_rating" => "meeting",
              "shared_notes" => "Emp grow - meet - incomplete"
            }
          }
        }

        # Create a snapshot
        snapshot = MaapSnapshot.build_for_employee_with_changes(
          employee_teammate: employee_teammate,
          creator_teammate: employee_teammate,
          change_type: 'bulk_check_in_finalization',
          reason: 'Testing check_in_data format',
          form_params: form_params
        )

        # Verify form_params are stored separately
        expect(snapshot.form_params).to eq(form_params)

        # Find assignments in the snapshot - maap_data should reflect DB state
        emp_growth_data = snapshot.maap_data['assignments'].find { |a| a['assignment_id'] == emp_growth_assignment.id }
        quarterly_data = snapshot.maap_data['assignments'].find { |a| a['assignment_id'] == quarterly_assignment.id }
        lifeline_data = snapshot.maap_data['assignments'].find { |a| a['assignment_id'] == lifeline_assignment.id }

        # maap_data should contain assignment_tenure data only (from DB)
        expect(emp_growth_data).to be_present
        expect(emp_growth_data['anticipated_energy_percentage']).to eq(50) # From DB
        expect(emp_growth_data.keys).to match_array(%w[assignment_id anticipated_energy_percentage rated_assignment])
        
        expect(quarterly_data).to be_present
        expect(quarterly_data['anticipated_energy_percentage']).to eq(30) # From DB
        expect(quarterly_data.keys).to match_array(%w[assignment_id anticipated_energy_percentage rated_assignment])
        
        expect(lifeline_data).to be_present
        expect(lifeline_data['anticipated_energy_percentage']).to eq(20) # From DB
        expect(lifeline_data.keys).to match_array(%w[assignment_id anticipated_energy_percentage rated_assignment])
        
        # maap_data should NOT contain check-in data (that's in form_params)
        expect(emp_growth_data).not_to have_key('official_check_in')
        expect(quarterly_data).not_to have_key('official_check_in')
        expect(lifeline_data).not_to have_key('official_check_in')
      end
    end
  end
end


