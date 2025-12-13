require 'rails_helper'

RSpec.describe 'People::Assignments', type: :request do
  let(:organization) { create(:organization, :company) }
  let(:manager_person) { create(:person) }
  let(:employee_person) { create(:person) }
  let!(:manager_teammate) { create(:teammate, person: manager_person, organization: organization) }
  let!(:employee_teammate) { create(:teammate, person: employee_person, organization: organization) }
  let(:assignment) { create(:assignment, company: organization, title: 'Test Assignment') }
  let!(:assignment_tenure) { create(:assignment_tenure, teammate: employee_teammate, assignment: assignment, started_at: 1.month.ago, ended_at: nil) }
  let!(:position_major_level) { create(:position_major_level, major_level: 1, set_name: 'Engineering') }
  let!(:position_type) { create(:position_type, organization: organization, external_title: 'Engineer', position_major_level: position_major_level) }
  let!(:position_level) { create(:position_level, position_major_level: position_major_level, level: '1.1') }
  let!(:position) { create(:position, position_type: position_type, position_level: position_level) }
  let!(:employment_tenure) { create(:employment_tenure, teammate: employee_teammate, position: position, company: organization, manager: manager_person, started_at: 1.year.ago, ended_at: nil) }

  before do
    # Set up manager with employment management permissions BEFORE signing in
    manager_teammate.update!(can_manage_employment: true, first_employed_at: 1.year.ago)
    # Create employment tenure if it doesn't exist
    EmploymentTenure.find_or_create_by!(teammate: manager_teammate, company: organization) do |et|
      et.position = position
      et.started_at = 1.year.ago
      et.ended_at = nil
    end
    # Ensure employee_teammate also has first_employed_at set
    employee_teammate.update!(first_employed_at: 1.year.ago) unless employee_teammate.first_employed_at

    # Sign in AFTER setting up permissions
    signed_in_teammate = sign_in_as_teammate_for_request(manager_person, organization)
    # Ensure the signed-in teammate has the permissions (in case it's a different instance)
    signed_in_teammate.update!(can_manage_employment: true, first_employed_at: 1.year.ago) if signed_in_teammate
  end

  describe 'GET #show' do
    context 'when manager is authorized' do
      it 'returns success' do
        get person_assignment_path(employee_person, assignment)
        expect(response).to have_http_status(:success)
      end

      it 'loads assignment data' do
        get person_assignment_path(employee_person, assignment)
        expect(assigns(:assignment)).to eq(assignment)
        expect(assigns(:person)).to eq(employee_person)
      end

      it 'loads check-in data' do
        check_in = create(:assignment_check_in, teammate: employee_teammate, assignment: assignment, check_in_started_on: Date.current)
        get person_assignment_path(employee_person, assignment)
        expect(assigns(:open_check_in)).to eq(check_in)
      end

      it 'loads tenure data' do
        get person_assignment_path(employee_person, assignment)
        expect(assigns(:tenure)).to eq(assignment_tenure)
      end

      it 'loads recent check-ins' do
        # Create finalized check-ins (not open) to avoid validation error
        check_in1 = create(:assignment_check_in, teammate: employee_teammate, assignment: assignment, check_in_started_on: 1.week.ago, employee_completed_at: 1.week.ago, manager_completed_at: 1.week.ago, official_check_in_completed_at: 1.week.ago)
        check_in2 = create(:assignment_check_in, teammate: employee_teammate, assignment: assignment, check_in_started_on: 2.weeks.ago, employee_completed_at: 2.weeks.ago, manager_completed_at: 2.weeks.ago, official_check_in_completed_at: 2.weeks.ago)
        get person_assignment_path(employee_person, assignment)
        expect(assigns(:recent_check_ins)).to include(check_in1, check_in2)
      end
    end

    context 'when employee accesses their own page' do
      before do
        sign_in_as_teammate_for_request(employee_person, organization)
      end

      it 'returns success' do
        get person_assignment_path(employee_person, assignment)
        expect(response).to have_http_status(:success)
      end
    end

    context 'when unauthorized user tries to access' do
      let(:other_person) { create(:person) }
      let!(:other_teammate) { create(:teammate, person: other_person, organization: organization) }

      before do
        sign_in_as_teammate_for_request(other_person, organization)
        create(:employment_tenure, teammate: other_teammate, company: organization, position: position)
      end

      it 'redirects with authorization error' do
        get person_assignment_path(employee_person, assignment)
        expect(response).to have_http_status(:redirect)
      end
    end
  end

  describe 'PATCH form submission (via check-ins controller)' do
    let(:organization_id) { organization.id }

    context 'when employee submits check-in data' do
      before do
        sign_in_as_teammate_for_request(employee_person, organization)
      end

      it 'saves employee check-in data with nested format' do
        check_in = AssignmentCheckIn.find_or_create_open_for(employee_teammate, assignment)
        
        patch organization_company_teammate_check_ins_path(organization, employee_teammate),
              params: {
                check_ins: {
                  assignment_check_ins: {
                    check_in.id => {
                      assignment_id: assignment.id,
                      actual_energy_percentage: 75,
                      employee_personal_alignment: 'love',
                      employee_rating: 'exceeding',
                      employee_private_notes: 'Great assignment!',
                      status: 'complete'
                    }
                  }
                }
              }

        check_in.reload
        expect(check_in.actual_energy_percentage).to eq(75)
        expect(check_in.employee_personal_alignment).to eq('love')
        expect(check_in.employee_rating).to eq('exceeding')
        expect(check_in.employee_private_notes).to eq('Great assignment!')
        expect(check_in.employee_completed_at).to be_present
      end

      it 'does not allow employee to update manager fields' do
        check_in = AssignmentCheckIn.find_or_create_open_for(employee_teammate, assignment)
        
        patch organization_company_teammate_check_ins_path(organization, employee_teammate),
              params: {
                check_ins: {
                  assignment_check_ins: {
                    check_in.id => {
                      assignment_id: assignment.id,
                      manager_rating: 'exceeding',
                      manager_private_notes: 'Manager notes',
                      status: 'complete'
                    }
                  }
                }
              }

        check_in.reload
        # Manager fields should not be updated when submitted as employee
        expect(check_in.manager_rating).to be_nil
        expect(check_in.manager_private_notes).to be_nil
      end
    end

    context 'when manager submits check-in data' do
      it 'saves manager check-in data' do
        check_in = AssignmentCheckIn.find_or_create_open_for(employee_teammate, assignment)
        
        patch organization_company_teammate_check_ins_path(organization, employee_teammate),
              params: {
                check_ins: {
                  assignment_check_ins: {
                    check_in.id => {
                      assignment_id: assignment.id,
                      manager_rating: 'meeting',
                      manager_private_notes: 'Good work',
                      status: 'complete'
                    }
                  }
                }
              }

        check_in.reload
        expect(check_in.manager_rating).to eq('meeting')
        expect(check_in.manager_private_notes).to eq('Good work')
        expect(check_in.manager_completed_at).to be_present
        expect(check_in.manager_completed_by).to eq(manager_person)
      end

      it 'does not allow manager to update employee fields' do
        check_in = AssignmentCheckIn.find_or_create_open_for(employee_teammate, assignment)
        original_energy = check_in.actual_energy_percentage
        original_alignment = check_in.employee_personal_alignment
        original_rating = check_in.employee_rating
        
        patch organization_company_teammate_check_ins_path(organization, employee_teammate),
              params: {
                check_ins: {
                  assignment_check_ins: {
                    check_in.id => {
                      assignment_id: assignment.id,
                      actual_energy_percentage: 80,
                      employee_personal_alignment: 'like',
                      employee_rating: 'exceeding',
                      status: 'complete'
                    }
                  }
                }
              }

        check_in.reload
        # Employee fields should not be updated when submitted as manager
        # Controller should filter these out via parameter permitting
        expect(check_in.actual_energy_percentage).to eq(original_energy)
        expect(check_in.employee_personal_alignment).to eq(original_alignment)
        expect(check_in.employee_rating).to eq(original_rating)
      end
    end

    context 'when form uses old flat format (expect failure)' do
      it 'does not save data with flat parameter format' do
        check_in = AssignmentCheckIn.find_or_create_open_for(employee_teammate, assignment)
        original_notes = check_in.employee_private_notes
        
        patch organization_company_teammate_check_ins_path(organization, employee_teammate),
              params: {
                "check_in_#{assignment.id}_employee_private_notes" => 'New notes',
                "check_in_#{assignment.id}_employee_complete" => '1'
              }

        check_in.reload
        # This should fail - flat format not handled
        expect(check_in.employee_private_notes).to eq(original_notes)
      end
    end
  end
end

