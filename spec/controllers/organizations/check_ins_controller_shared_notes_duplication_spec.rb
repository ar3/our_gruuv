require 'rails_helper'

RSpec.describe Organizations::CheckInsController, type: :controller do
  let(:organization) { create(:organization) }
  let(:manager) { create(:person) }
  let(:employee) { create(:person) }
  let(:assignment1) { create(:assignment, company: organization, title: 'Employee Growth Plan Champion') }
  let(:assignment2) { create(:assignment, company: organization, title: 'Quarterly Conversation Coordinator') }
  let(:check_in1) { create(:assignment_check_in, person: employee, assignment: assignment1, id: 80) }
  let(:check_in2) { create(:assignment_check_in, person: employee, assignment: assignment2, id: 81) }

  before do
    # Set up employment tenures
    create(:employment_tenure, person: manager, company: organization)
    create(:employment_tenure, person: employee, company: organization)
    
    # Set up manager permissions
    create(:person_organization_access, person: manager, organization: organization, can_manage_employment: true)
    
    # Set up assignment tenures
    create(:assignment_tenure, person: employee, assignment: assignment1, anticipated_energy_percentage: 50)
    create(:assignment_tenure, person: employee, assignment: assignment2, anticipated_energy_percentage: 30)
    
    # Set up check-ins with employee and manager completed
    check_in1.update!(
      employee_completed_at: Time.current,
      manager_completed_at: Time.current,
      manager_completed_by: manager
    )
    check_in2.update!(
      employee_completed_at: Time.current,
      manager_completed_at: Time.current,
      manager_completed_by: manager
    )
    
    # Set up session
    session[:current_person_id] = manager.id
  end

  describe 'POST #bulk_finalize' do
    context 'when shared notes are provided for different assignments' do
      it 'should not duplicate shared notes across assignments' do
        # Form params with different shared notes for each assignment
        form_params = {
          "check_in_#{check_in1.id}_shared_notes" => 'emp grow - not set',
          "check_in_#{check_in2.id}_shared_notes" => 'quarterly - working',
          "check_in_#{check_in1.id}_final_rating" => '4',
          "check_in_#{check_in2.id}_final_rating" => '3',
          "check_in_#{check_in1.id}_close_rating" => 'true',
          "check_in_#{check_in2.id}_close_rating" => 'true'
        }

        patch :bulk_finalize_check_ins, params: { id: employee.id, organization_id: organization.id }.merge(form_params)

        # Get the created MAAP snapshot
        maap_snapshot = MaapSnapshot.last
        puts "MAAP snapshot created: #{maap_snapshot.present?}"
        puts "Response status: #{response.status}"
        puts "Response location: #{response.location}" if response.redirect?
        
        # Find assignments in the snapshot
        assignment1_data = maap_snapshot.maap_data['assignments'].find { |a| a['id'] == assignment1.id }
        assignment2_data = maap_snapshot.maap_data['assignments'].find { |a| a['id'] == assignment2.id }
        
        puts "Assignment 1 (#{assignment1.title}) shared_notes: '#{assignment1_data['official_check_in']['shared_notes']}'"
        puts "Assignment 2 (#{assignment2.title}) shared_notes: '#{assignment2_data['official_check_in']['shared_notes']}'"
        
        # Verify shared notes are not duplicated
        expect(assignment1_data['official_check_in']['shared_notes']).to eq('emp grow - not set')
        expect(assignment2_data['official_check_in']['shared_notes']).to eq('quarterly - working')
        
        # Verify they are different
        expect(assignment1_data['official_check_in']['shared_notes']).not_to eq(assignment2_data['official_check_in']['shared_notes'])
      end
    end
  end
end
