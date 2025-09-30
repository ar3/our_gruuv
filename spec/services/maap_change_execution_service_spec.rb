require 'rails_helper'

RSpec.describe MaapChangeExecutionService do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:manager) { create(:person) }
  let(:assignment) { create(:assignment, company: organization) }
  let(:service) { described_class.new(maap_snapshot: maap_snapshot, current_user: current_user) }

  before do
    create(:employment_tenure, person: manager, company: organization)
    create(:employment_tenure, person: person, company: organization)
  end

  describe '#execute!' do
    context 'with assignment_management change type' do
      let(:current_user) { manager }
      let(:maap_snapshot) do
        create(:maap_snapshot,
               employee: person,
               created_by: manager,
               company: organization,
               change_type: 'assignment_management',
               maap_data: maap_data)
      end

      context 'when updating assignment tenure' do
        let(:maap_data) do
          {
            'assignments' => [
              {
                'id' => assignment.id,
                'tenure' => {
                  'anticipated_energy_percentage' => 75,
                  'started_at' => Date.current.to_s
                }
              }
            ]
          }
        end

        it 'updates the assignment tenure' do
          expect_any_instance_of(AssignmentTenureService).to receive(:update_tenure)
            .with(anticipated_energy_percentage: 75, started_at: Date.current.to_s)

          result = service.execute!
          expect(result).to be true
        end
      end

      context 'when updating manager check-in fields' do
        let(:check_in) do
          create(:assignment_check_in,
                 person: person,
                 assignment: assignment,
                 manager_rating: 'exceeding',
                 manager_private_notes: 'Old notes')
        end
        let(:maap_data) do
          {
            'assignments' => [
              {
                'id' => assignment.id,
                'manager_check_in' => {
                  'manager_rating' => 'meeting',
                  'manager_private_notes' => 'New notes',
                  'manager_completed_at' => Time.current.iso8601
                }
              }
            ]
          }
        end

        before do
          allow_any_instance_of(PersonPolicy).to receive(:manage_assignments?).and_return(true)
          check_in # Create the check-in
        end

        it 'updates manager check-in fields' do
          result = service.execute!
          expect(result).to be true

          check_in.reload
          expect(check_in.manager_rating).to eq('meeting')
          expect(check_in.manager_private_notes).to eq('New notes')
          expect(check_in.manager_completed_at).to be_present
          expect(check_in.manager_completed_by).to eq(manager)
        end
      end

      context 'when unchecking manager completion' do
        let(:check_in) do
          create(:assignment_check_in,
                 person: person,
                 assignment: assignment,
                 manager_rating: 'meeting',
                 manager_private_notes: 'Good work',
                 manager_completed_at: Time.current,
                 manager_completed_by: manager)
        end
        let(:maap_data) do
          {
            'assignments' => [
              {
                'id' => assignment.id,
                'manager_check_in' => {
                  'manager_rating' => 'meeting',
                  'manager_private_notes' => 'Good work',
                  'manager_completed_at' => nil,
                  'manager_completed_by_id' => nil
                }
              }
            ]
          }
        end

        before do
          allow_any_instance_of(PersonPolicy).to receive(:manage_assignments?).and_return(true)
          check_in # Create the check-in
        end

        it 'unchecks manager completion' do
          result = service.execute!
          expect(result).to be true

          check_in.reload
          expect(check_in.manager_completed_at).to be_nil
          expect(check_in.manager_completed_by).to be_nil
          expect(check_in.manager_rating).to eq('meeting')
          expect(check_in.manager_private_notes).to eq('Good work')
        end
      end

      context 'when updating employee check-in fields' do
        let(:current_user) { person }
        let(:check_in) do
          create(:assignment_check_in,
                 person: person,
                 assignment: assignment,
                 actual_energy_percentage: 50,
                 employee_rating: 'exceeding')
        end
        let(:maap_data) do
          {
            'assignments' => [
              {
                'id' => assignment.id,
                'employee_check_in' => {
                  'actual_energy_percentage' => 75,
                  'employee_rating' => 'meeting',
                  'employee_private_notes' => 'Feeling good',
                  'employee_personal_alignment' => 'love',
                  'employee_completed_at' => Time.current.iso8601
                }
              }
            ]
          }
        end

        before do
          check_in # Create the check-in
        end

        it 'updates employee check-in fields' do
          result = service.execute!
          expect(result).to be true

          check_in.reload
          expect(check_in.actual_energy_percentage).to eq(75)
          expect(check_in.employee_rating).to eq('meeting')
          expect(check_in.employee_private_notes).to eq('Feeling good')
          expect(check_in.employee_personal_alignment).to eq('love')
          expect(check_in.employee_completed_at).to be_present
        end
      end

      context 'when unchecking employee completion' do
        let(:current_user) { person }
        let(:check_in) do
          create(:assignment_check_in,
                 person: person,
                 assignment: assignment,
                 actual_energy_percentage: 75,
                 employee_rating: 'meeting',
                 employee_completed_at: Time.current)
        end
        let(:maap_data) do
          {
            'assignments' => [
              {
                'id' => assignment.id,
                'employee_check_in' => {
                  'actual_energy_percentage' => 75,
                  'employee_rating' => 'meeting',
                  'employee_private_notes' => 'Feeling good',
                  'employee_personal_alignment' => 'love',
                  'employee_completed_at' => nil
                }
              }
            ]
          }
        end

        before do
          check_in # Create the check-in
        end

        it 'unchecks employee completion' do
          result = service.execute!
          expect(result).to be true

          check_in.reload
          expect(check_in.employee_completed_at).to be_nil
          expect(check_in.actual_energy_percentage).to eq(75)
          expect(check_in.employee_rating).to eq('meeting')
        end
      end

      context 'when updating official check-in fields' do
        let(:current_user) { manager }
        let(:check_in) do
          create(:assignment_check_in,
                 person: person,
                 assignment: assignment,
                 official_rating: 'exceeding',
                 shared_notes: 'Old notes')
        end
        let(:maap_data) do
          {
            'assignments' => [
              {
                'id' => assignment.id,
                'official_check_in' => {
                  'official_rating' => 'meeting',
                  'shared_notes' => 'New notes',
                  'official_check_in_completed_at' => Time.current.iso8601
                }
              }
            ]
          }
        end

        before do
          allow_any_instance_of(PersonPolicy).to receive(:manage_assignments?).and_return(true)
          check_in # Create the check-in
        end

        it 'updates official check-in fields' do
          result = service.execute!
          expect(result).to be true

          check_in.reload
          expect(check_in.official_rating).to eq('meeting')
          expect(check_in.shared_notes).to eq('New notes')
          expect(check_in.official_check_in_completed_at).to be_present
          expect(check_in.finalized_by).to eq(manager)
        end
      end

      context 'when creating a new check-in' do
        let(:current_user) { manager }
        let(:maap_data) do
          {
            'assignments' => [
              {
                'id' => assignment.id,
                'manager_check_in' => {
                  'manager_rating' => 'meeting',
                  'manager_private_notes' => 'New check-in',
                  'manager_completed_at' => Time.current.iso8601
                }
              }
            ]
          }
        end

        before do
          allow_any_instance_of(PersonPolicy).to receive(:manage_assignments?).and_return(true)
        end

        it 'creates a new check-in' do
          expect { service.execute! }.to change(AssignmentCheckIn, :count).by(1)

          check_in = AssignmentCheckIn.last
          expect(check_in.person).to eq(person)
          expect(check_in.assignment).to eq(assignment)
          expect(check_in.manager_rating).to eq('meeting')
          expect(check_in.manager_private_notes).to eq('New check-in')
          expect(check_in.manager_completed_at).to be_present
        end
      end

      context 'when user lacks authorization' do
        let(:current_user) { person } # Employee trying to update manager fields
        let(:check_in) do
          create(:assignment_check_in,
                 person: person,
                 assignment: assignment,
                 manager_rating: 'exceeding')
        end
        let(:maap_data) do
          {
            'assignments' => [
              {
                'id' => assignment.id,
                'manager_check_in' => {
                  'manager_rating' => 'meeting',
                  'manager_private_notes' => 'Should not update'
                }
              }
            ]
          }
        end

        before do
          allow_any_instance_of(PersonPolicy).to receive(:manage_assignments?).and_return(false)
          check_in # Create the check-in
        end

        it 'does not update unauthorized fields' do
          result = service.execute!
          expect(result).to be true

          check_in.reload
          expect(check_in.manager_rating).to eq('exceeding') # Unchanged
        end
      end

      context 'when admin bypass is enabled' do
        let(:current_user) { create(:person, og_admin: true) }
        let(:check_in) do
          create(:assignment_check_in,
                 person: person,
                 assignment: assignment,
                 manager_rating: 'exceeding')
        end
        let(:maap_data) do
          {
            'assignments' => [
              {
                'id' => assignment.id,
                'manager_check_in' => {
                  'manager_rating' => 'meeting',
                  'manager_private_notes' => 'Admin update'
                }
              }
            ]
          }
        end

        before do
          check_in # Create the check-in
        end

        it 'allows admin to update any fields' do
          result = service.execute!
          expect(result).to be true

          check_in.reload
          expect(check_in.manager_rating).to eq('meeting')
          expect(check_in.manager_private_notes).to eq('Admin update')
        end
      end
    end

    context 'with unsupported change type' do
      let(:current_user) { manager }
      let(:maap_snapshot) do
        create(:maap_snapshot,
               employee: person,
               created_by: manager,
               company: organization,
               change_type: 'assignment_management',
               maap_data: {})
      end

      before do
        # Mock the service to return false for unsupported type
        allow(service).to receive(:execute!).and_call_original
        allow(service).to receive(:execute_assignment_management).and_return(false)
      end

      it 'returns false' do
        result = service.execute!
        expect(result).to be false
      end
    end

    context 'when an error occurs' do
      let(:current_user) { manager }
      let(:maap_snapshot) do
        create(:maap_snapshot,
               employee: person,
               created_by: manager,
               company: organization,
               change_type: 'assignment_management',
               maap_data: { 'assignments' => [{ 'id' => 99999 }] }) # Non-existent assignment
      end

      it 'logs the error and returns false' do
        expect(Rails.logger).to receive(:error).with(/Error executing MAAP changes/)
        expect(Rails.logger).to receive(:error).with(any_args)

        result = service.execute!
        expect(result).to be false
      end
    end
  end
end
