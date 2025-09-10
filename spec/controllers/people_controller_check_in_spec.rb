require 'rails_helper'

RSpec.describe PeopleController, type: :controller do
  let(:manager) { create(:person) }
  let(:employee) { create(:person) }
  let(:assignment) { create(:assignment) }
  let!(:check_in) { create(:assignment_check_in, person: employee, assignment: assignment) }

  before do
    sign_in manager
    allow(controller).to receive(:current_person).and_return(manager)
  end

  describe 'GET #check_in' do
    context 'when user has manager permissions' do
      before do
        allow(controller).to receive(:authorize).and_return(true)
      end

      it 'assigns ready for finalization check-ins' do
        check_in.complete_employee_side!
        check_in.complete_manager_side!
        
        get :check_in, params: { id: employee.id }
        
        expect(assigns(:ready_for_finalization)).to include(check_in)
      end

      it 'excludes check-ins not ready for finalization' do
        check_in.complete_employee_side!
        # Manager not completed
        
        get :check_in, params: { id: employee.id }
        
        expect(assigns(:ready_for_finalization)).not_to include(check_in)
      end

      it 'excludes officially completed check-ins' do
        check_in.complete_employee_side!
        check_in.complete_manager_side!
        check_in.finalize_check_in!(final_rating: 'meeting')
        
        get :check_in, params: { id: employee.id }
        
        expect(assigns(:ready_for_finalization)).not_to include(check_in)
      end
    end
  end

  describe 'PATCH #finalize_check_in' do
    let(:valid_params) do
      {
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
        allow(controller).to receive(:authorize).and_return(true)
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
        expect(response).to redirect_to(check_in_person_path(employee))
        expect(flash[:notice]).to eq('Check-in finalized successfully.')
      end
    end

    context 'when check-in is not ready for finalization' do
      before do
        # Only employee completed, manager not completed
        check_in.complete_employee_side!
        allow(controller).to receive(:authorize).and_return(true)
      end

      it 'does not finalize the check-in' do
        expect {
          patch :finalize_check_in, params: valid_params
        }.not_to change { check_in.reload.official_check_in_completed_at }
      end

      it 'redirects with error message' do
        patch :finalize_check_in, params: valid_params
        expect(response).to redirect_to(check_in_person_path(employee))
        expect(flash[:alert]).to eq('Check-in is not ready for finalization. Both employee and manager must complete their sections first.')
      end
    end

    context 'when final rating is missing' do
      before do
        check_in.complete_employee_side!
        check_in.complete_manager_side!
        allow(controller).to receive(:authorize).and_return(true)
      end

      let(:invalid_params) { valid_params.except(:final_rating) }

      it 'does not finalize the check-in' do
        expect {
          patch :finalize_check_in, params: invalid_params
        }.not_to change { check_in.reload.official_check_in_completed_at }
      end

      it 'redirects with error message' do
        patch :finalize_check_in, params: invalid_params
        expect(response).to redirect_to(check_in_person_path(employee))
        expect(flash[:alert]).to eq('Final rating is required to finalize the check-in.')
      end
    end

    context 'when check-in is already finalized' do
      before do
        check_in.complete_employee_side!
        check_in.complete_manager_side!
        check_in.finalize_check_in!(final_rating: 'meeting')
        allow(controller).to receive(:authorize).and_return(true)
      end

      it 'does not finalize again' do
        original_time = check_in.official_check_in_completed_at
        patch :finalize_check_in, params: valid_params
        expect(check_in.reload.official_check_in_completed_at).to eq(original_time)
      end

      it 'redirects with error message' do
        patch :finalize_check_in, params: valid_params
        expect(response).to redirect_to(check_in_person_path(employee))
        expect(flash[:alert]).to eq('Check-in is not ready for finalization. Both employee and manager must complete their sections first.')
      end
    end
  end
end
