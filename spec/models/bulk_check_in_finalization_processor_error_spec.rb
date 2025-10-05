require 'rails_helper'

RSpec.describe 'BulkCheckInFinalizationProcessor Error Reproduction', type: :model do
  let(:organization) { create(:organization) }
  let(:employee) { create(:person) }
  let(:employee_teammate) { create(:teammate, person: employee, organization: organization) }
  let(:ability) { create(:ability, organization: organization, name: 'Test Ability') }
  let(:assignment) { create(:assignment, company: organization, title: 'Test Assignment') }

  before do
    # Set up employment tenure
    create(:employment_tenure, teammate: employee_teammate, company: organization)
    
    # Set up assignment tenure
    create(:assignment_tenure, teammate: employee_teammate, assignment: assignment, anticipated_energy_percentage: 50)
    
    # Set up check-in
    create(:assignment_check_in, teammate: employee_teammate, assignment: assignment, employee_completed_at: Time.current, manager_completed_at: Time.current)
    
    # Set up person milestone (this will cause the error)
    create(:person_milestone, teammate: employee_teammate, ability: ability, milestone_level: 1)
  end

  describe 'BulkCheckInFinalizationProcessor' do
    context 'when processing milestones data' do
      it 'should fail by reproducing the NoMethodError for Ability#title' do
        # Create a snapshot without maap_data
        snapshot = MaapSnapshot.build_for_employee_without_maap_data(
          employee: employee,
          created_by: employee,
          change_type: 'bulk_check_in_finalization',
          reason: 'Testing milestone processing error',
          form_params: {}
        )

        # Verify we have milestones to process
        expect(employee_teammate.person_milestones.count).to be > 0

        # This should now work correctly after fixing the attribute names
        expect {
          snapshot.process_with_processor!
        }.not_to raise_error
        
        # Verify the snapshot was processed successfully
        expect(snapshot.maap_data).to be_present
        expect(snapshot.maap_data['milestones']).to be_an(Array)
        expect(snapshot.maap_data['milestones'].length).to eq(1)
        
        milestone_data = snapshot.maap_data['milestones'].first
        expect(milestone_data['ability_title']).to eq('Test Ability')
        expect(milestone_data['milestone_level']).to eq(1)
      end
    end
  end
end
