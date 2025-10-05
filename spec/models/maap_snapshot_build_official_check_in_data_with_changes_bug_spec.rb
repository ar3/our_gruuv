require 'rails_helper'

RSpec.describe MaapSnapshot, type: :model do
  let(:organization) { create(:organization) }
  let(:employee) { create(:person) }
  let(:employee_teammate) { create(:teammate, person: employee, organization: organization) }
  let(:assignment) { create(:assignment, company: organization, title: 'Test Assignment') }

  before do
    # Set up employment tenure
    create(:employment_tenure, teammate: employee_teammate, company: organization)
    
    # Set up assignment tenure
    create(:assignment_tenure, teammate: employee_teammate, assignment: assignment, anticipated_energy_percentage: 50)
    
    # Set up check-in with existing data
    create(:assignment_check_in, teammate: employee_teammate, assignment: assignment, shared_notes: 'Existing shared notes', official_rating: 'exceeding')
  end

  describe 'build_official_check_in_data_with_changes method' do
    context 'when there are no form changes' do
      it 'should return the current check-in data instead of nil' do
        check_in = AssignmentCheckIn.where(teammate: employee_teammate, assignment: assignment).first
        
        # Test with empty form params
        result = MaapSnapshot.build_official_check_in_data_with_changes(check_in, {}, assignment.id)
        
        # Debug output
        puts "Check-in ID: #{check_in.id}"
        puts "Check-in shared_notes: '#{check_in.shared_notes}'"
        puts "Check-in official_rating: '#{check_in.official_rating}'"
        puts "Result: #{result.inspect}"
        
        # This should fail because the method returns nil instead of current check-in data
        expect(result).not_to be_nil
        expect(result[:shared_notes]).to eq('Existing shared notes')
        expect(result[:official_rating]).to eq('exceeding')
      end
    end
  end
end
