require 'rails_helper'

RSpec.describe Organizations::PeopleController, type: :controller do
  let(:organization) { create(:organization) }
  let(:manager) { create(:person, current_organization: organization) }
  let(:employee) { create(:person, current_organization: organization) }
  let(:assignment) { create(:assignment, company: organization) }
  let!(:check_in) { create(:assignment_check_in, person: employee, assignment: assignment) }

  before do
    session[:current_person_id] = manager.id
    allow(controller).to receive(:current_person).and_return(manager)
    # Set up employment for manager
    create(:employment_tenure, person: manager, company: organization)
    # Set up organization access for manager
    create(:person_organization_access, person: manager, organization: organization, can_manage_employment: true)
  end

  describe 'GET #check_in' do
    context 'when user has manager permissions' do
      before do
        # Set up proper authorization by allowing the policy method
        allow_any_instance_of(PersonPolicy).to receive(:manager?).and_return(true)
      end

      it 'assigns ready for finalization check-ins' do
        check_in.complete_employee_side!
        check_in.complete_manager_side!
        
        get :check_in, params: { organization_id: organization.id, id: employee.id }
        
        expect(assigns(:ready_for_finalization)).to include(check_in)
      end

      it 'excludes check-ins not ready for finalization' do
        check_in.complete_employee_side!
        # Manager not completed
        
        get :check_in, params: { organization_id: organization.id, id: employee.id }
        
        expect(assigns(:ready_for_finalization)).not_to include(check_in)
      end

      it 'excludes officially completed check-ins' do
        check_in.complete_employee_side!
        check_in.complete_manager_side!
        check_in.finalize_check_in!(final_rating: 'meeting')
        
        get :check_in, params: { organization_id: organization.id, id: employee.id }
        
        expect(assigns(:ready_for_finalization)).not_to include(check_in)
      end
    end
  end

  describe 'PATCH #finalize_check_in' do
    let(:valid_params) do
      {
        organization_id: organization.id,
        id: employee.id,
        check_in_id: check_in.id,
        final_rating: 'exceeding',
        shared_notes: 'Great work!'
      }
    end

    context 'when check-in is ready for finalization' do
      before do
        check_in.complete_employee_side!
        check_in.complete_manager_side!
        # Set up proper authorization by allowing the policy method
        allow_any_instance_of(PersonPolicy).to receive(:manager?).and_return(true)
      end

      it 'finalizes the check-in successfully' do
        expect {
          patch :finalize_check_in, params: valid_params
        }.to change { check_in.reload.official_check_in_completed_at }.from(nil)
      end

      it 'sets the final rating' do
        patch :finalize_check_in, params: valid_params
        expect(check_in.reload.official_rating).to eq('exceeding')
      end

      it 'updates shared notes' do
        patch :finalize_check_in, params: valid_params
        expect(check_in.reload.shared_notes).to eq('Great work!')
      end

      it 'redirects to check_in page with success message' do
        patch :finalize_check_in, params: valid_params
        expect(response).to redirect_to(check_in_organization_person_path(organization, employee))
        expect(flash[:notice]).to eq('Check-in finalized successfully.')
      end
    end

    context 'when check-in is not ready for finalization' do
      before do
        # Only employee completed, manager not completed
        check_in.complete_employee_side!
        # Set up proper authorization by allowing the policy method
        allow_any_instance_of(PersonPolicy).to receive(:manager?).and_return(true)
      end

      it 'does not finalize the check-in' do
        expect {
          patch :finalize_check_in, params: valid_params
        }.not_to change { check_in.reload.official_check_in_completed_at }
      end

      it 'redirects with error message' do
        patch :finalize_check_in, params: valid_params
        expect(response).to redirect_to(check_in_organization_person_path(organization, employee))
        expect(flash[:alert]).to eq('Check-in is not ready for finalization. Both employee and manager must complete their sections first.')
      end
    end

    context 'when final rating is missing' do
      before do
        check_in.complete_employee_side!
        check_in.complete_manager_side!
        # Set up proper authorization by allowing the policy method
        allow_any_instance_of(PersonPolicy).to receive(:manager?).and_return(true)
      end

      let(:invalid_params) { valid_params.except(:final_rating) }

      it 'does not finalize the check-in' do
        expect {
          patch :finalize_check_in, params: invalid_params
        }.not_to change { check_in.reload.official_check_in_completed_at }
      end

      it 'redirects with error message' do
        patch :finalize_check_in, params: invalid_params
        expect(response).to redirect_to(check_in_organization_person_path(organization, employee))
        expect(flash[:alert]).to eq('Final rating is required to finalize the check-in.')
      end
    end

    context 'when check-in is already finalized' do
      before do
        check_in.complete_employee_side!
        check_in.complete_manager_side!
        check_in.finalize_check_in!(final_rating: 'meeting')
        # Set up proper authorization by allowing the policy method
        allow_any_instance_of(PersonPolicy).to receive(:manager?).and_return(true)
      end

      it 'does not finalize again' do
        original_time = check_in.official_check_in_completed_at
        patch :finalize_check_in, params: valid_params
        expect(check_in.reload.official_check_in_completed_at).to eq(original_time)
      end

      it 'redirects with error message' do
        patch :finalize_check_in, params: valid_params
        expect(response).to redirect_to(check_in_organization_person_path(organization, employee))
        expect(flash[:alert]).to eq('Check-in is not ready for finalization. Both employee and manager must complete their sections first.')
      end
    end
  end

  describe 'concurrent update protection' do
    let(:check_in_data) do
      {
        'employee_check_in' => {
          'actual_energy_percentage' => 80,
          'employee_rating' => 'exceeding',
          'employee_private_notes' => 'Employee notes',
          'employee_personal_alignment' => 'love'
        },
        'manager_check_in' => {
          'manager_rating' => 'meeting',
          'manager_private_notes' => 'Manager notes'
        }
      }
    end

    context 'when employee updates their fields' do
      before do
        session[:current_person_id] = employee.id
        allow(controller).to receive(:current_person).and_return(employee)
      end

      it 'only updates employee fields and preserves manager fields' do
        # Set initial manager data
        check_in.update!(
          manager_rating: 'working_to_meet',
          manager_private_notes: 'Original manager notes'
        )

        # Employee updates their fields
        controller.send(:update_check_in_fields, check_in, check_in_data)

        check_in.reload
        # Employee fields should be updated
        expect(check_in.actual_energy_percentage).to eq(80)
        expect(check_in.employee_rating).to eq('exceeding')
        expect(check_in.employee_private_notes).to eq('Employee notes')
        expect(check_in.employee_personal_alignment).to eq('love')
        
        # Manager fields should be preserved
        expect(check_in.manager_rating).to eq('working_to_meet')
        expect(check_in.manager_private_notes).to eq('Original manager notes')
      end

      it 'does not update manager fields even if provided' do
        # Set initial manager data
        check_in.update!(
          manager_rating: 'working_to_meet',
          manager_private_notes: 'Original manager notes'
        )

        # Employee tries to update manager fields (should be ignored)
        controller.send(:update_check_in_fields, check_in, check_in_data)

        check_in.reload
        # Manager fields should remain unchanged
        expect(check_in.manager_rating).to eq('working_to_meet')
        expect(check_in.manager_private_notes).to eq('Original manager notes')
      end
    end

    context 'when manager updates their fields' do
      before do
        session[:current_person_id] = manager.id
        allow(controller).to receive(:current_person).and_return(manager)
        # Mock manager permissions
        allow(controller).to receive(:policy).with(employee).and_return(
          double(manage_assignments?: true)
        )
      end

      it 'only updates manager fields and preserves employee fields' do
        # Set initial employee data
        check_in.update!(
          actual_energy_percentage: 60,
          employee_rating: 'working_to_meet',
          employee_private_notes: 'Original employee notes',
          employee_personal_alignment: 'neutral'
        )

        # Manager updates their fields
        controller.send(:update_check_in_fields, check_in, check_in_data)

        check_in.reload
        # Manager fields should be updated
        expect(check_in.manager_rating).to eq('meeting')
        expect(check_in.manager_private_notes).to eq('Manager notes')
        
        # Employee fields should be preserved
        expect(check_in.actual_energy_percentage).to eq(60)
        expect(check_in.employee_rating).to eq('working_to_meet')
        expect(check_in.employee_private_notes).to eq('Original employee notes')
        expect(check_in.employee_personal_alignment).to eq('neutral')
      end

      it 'does not update employee fields even if provided' do
        # Set initial employee data
        check_in.update!(
          actual_energy_percentage: 60,
          employee_rating: 'working_to_meet',
          employee_private_notes: 'Original employee notes',
          employee_personal_alignment: 'neutral'
        )

        # Manager tries to update employee fields (should be ignored)
        controller.send(:update_check_in_fields, check_in, check_in_data)

        check_in.reload
        # Employee fields should remain unchanged
        expect(check_in.actual_energy_percentage).to eq(60)
        expect(check_in.employee_rating).to eq('working_to_meet')
        expect(check_in.employee_private_notes).to eq('Original employee notes')
        expect(check_in.employee_personal_alignment).to eq('neutral')
      end
    end

    context 'when admin updates fields' do
      let(:admin) { create(:person, og_admin: true) }

      before do
        session[:current_person_id] = admin.id
        allow(controller).to receive(:current_person).and_return(admin)
      end

      it 'can update both employee and manager fields' do
        controller.send(:update_check_in_fields, check_in, check_in_data)

        check_in.reload
        # Both employee and manager fields should be updated
        expect(check_in.actual_energy_percentage).to eq(80)
        expect(check_in.employee_rating).to eq('exceeding')
        expect(check_in.employee_private_notes).to eq('Employee notes')
        expect(check_in.employee_personal_alignment).to eq('love')
        expect(check_in.manager_rating).to eq('meeting')
        expect(check_in.manager_private_notes).to eq('Manager notes')
      end
    end
  end
end
