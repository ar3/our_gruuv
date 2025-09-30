require 'rails_helper'

RSpec.describe 'Manager Completed Uncheck Bug', type: :request do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:manager) { create(:person) }
  let(:assignment) { create(:assignment, company: organization) }
  
  describe 'executing changes that uncheck manager_completed' do
    before do
      # Sign in the manager
      allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(manager)
      allow_any_instance_of(ApplicationController).to receive(:authenticate_person!)
      
      # Set up employment tenures
      create(:employment_tenure, person: manager, company: organization)
      create(:employment_tenure, person: person, company: organization)
      
      # Grant manager permissions
      create(:person_organization_access, person: manager, organization: organization, can_manage_employment: true, can_manage_maap: true)
      
      # Set up current state: manager has completed the check-in
      create(:assignment_tenure, 
             person: person, 
             assignment: assignment, 
             anticipated_energy_percentage: 50,
             started_at: Date.current)
      
      # Create a check-in that is currently manager_completed
      @check_in = create(:assignment_check_in,
                        person: person,
                        assignment: assignment,
                        manager_rating: 'meeting',
                        manager_private_notes: 'Good work',
                        manager_completed_at: Time.current, # Currently completed
                        manager_completed_by: manager)
      
      # Create a MaapSnapshot that proposes to uncheck manager_completed
      @snapshot = create(:maap_snapshot,
                        employee: person,
                        created_by: manager,
                        company: organization,
                        change_type: 'assignment_management',
                        reason: 'Unchecking manager completion',
                        maap_data: {
                          'assignments' => [
                            {
                              'id' => assignment.id,
                              'tenure' => {
                                'started_at' => Date.current.to_s,
                                'anticipated_energy_percentage' => 50
                              },
                              'manager_check_in' => {
                                'manager_rating' => 'meeting',
                                'manager_completed_at' => nil, # Proposing to uncheck
                                'manager_private_notes' => 'Good work',
                                'manager_completed_by_id' => nil # Proposing to uncheck
                              },
                              'employee_check_in' => nil,
                              'official_check_in' => nil
                            }
                          ],
                          'employment_tenure' => {
                            'seat_id' => nil,
                            'manager_id' => manager.id,
                            'started_at' => Date.current.to_s,
                            'position_id' => 1
                          },
                          'milestones' => [],
                          'aspirations' => []
                        },
                        form_params: {
                          "check_in_#{assignment.id}_manager_complete" => "0" # Explicitly unchecked
                        })
    end
    
    it 'should set manager_completed_at to nil when manager_complete is unchecked' do
      # Verify initial state: manager is completed
      expect(@check_in.reload.manager_completed_at).to be_present
      expect(@check_in.manager_completed_by).to eq(manager)
      
      # Execute the changes
      post process_changes_organization_person_path(organization, person, @snapshot)
      
      # Follow the redirect to process_changes
      follow_redirect!
      
      # Verify the check-in was updated
      @check_in.reload
      
      # This should fail - the bug is that manager_completed_at is not being set to nil
      expect(@check_in.manager_completed_at).to be_nil, 
        "Expected manager_completed_at to be nil after unchecking, but it was #{@check_in.manager_completed_at}"
      
      expect(@check_in.manager_completed_by).to be_nil,
        "Expected manager_completed_by to be nil after unchecking, but it was #{@check_in.manager_completed_by}"
    end
    
    it 'should maintain other manager fields when unchecking completion' do
      # Execute the changes
      post process_changes_organization_person_path(organization, person, @snapshot)
      
      # Don't follow redirect, just check the response
      expect(response).to have_http_status(:redirect)
      
      # Verify other fields are maintained
      @check_in.reload
      expect(@check_in.manager_rating).to eq('meeting')
      expect(@check_in.manager_private_notes).to eq('Good work')
    end
  end
end
