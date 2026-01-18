require 'rails_helper'

RSpec.describe CheckInCompletionService, type: :service do
  let(:organization) { create(:organization, :company) }
  let(:employee) { create(:person) }
  let(:manager) { create(:person) }
  let(:employee_teammate) { create(:teammate, person: employee, organization: organization) }
  let(:manager_teammate) { CompanyTeammate.create!(person: manager, organization: organization) }

  let!(:employment_tenure) { create(:employment_tenure, teammate: employee_teammate, company: organization, manager_teammate: manager_teammate) }

  describe 'AssignmentCheckIn' do
    let(:assignment) { create(:assignment, company: organization) }
    let(:check_in) { create(:assignment_check_in, teammate: employee_teammate, assignment: assignment) }

    context 'when employee completes (manager not done)' do
      it 'detects completion and returns employee_only state' do
        service = CheckInCompletionService.new(check_in)
        service.complete_employee_side!

        expect(service.completion_detected?).to be true
        expect(service.completion_state).to eq(:employee_only)
        expect(check_in.reload.employee_completed?).to be true
        expect(check_in.manager_completed?).to be false
      end
    end

    context 'when manager completes (employee not done)' do
      it 'detects completion and returns manager_only state' do
        service = CheckInCompletionService.new(check_in)
        service.complete_manager_side!(completed_by: manager_teammate)

        expect(service.completion_detected?).to be true
        expect(service.completion_state).to eq(:manager_only)
        expect(check_in.reload.manager_completed?).to be true
        expect(check_in.employee_completed?).to be false
      end
    end

    context 'when employee completes and manager already completed' do
      before do
        check_in.update!(manager_completed_at: Time.current, manager_completed_by_teammate: manager_teammate)
      end

      it 'detects completion and returns both_complete state' do
        service = CheckInCompletionService.new(check_in)
        service.complete_employee_side!

        expect(service.completion_detected?).to be true
        expect(service.completion_state).to eq(:both_complete)
        expect(check_in.reload.employee_completed?).to be true
        expect(check_in.manager_completed?).to be true
      end
    end

    context 'when manager completes and employee already completed' do
      before do
        check_in.update!(employee_completed_at: Time.current)
      end

      it 'detects completion and returns both_complete state' do
        service = CheckInCompletionService.new(check_in)
        service.complete_manager_side!(completed_by: manager)

        expect(service.completion_detected?).to be true
        expect(service.completion_state).to eq(:both_complete)
        expect(check_in.reload.employee_completed?).to be true
        expect(check_in.manager_completed?).to be true
      end
    end

    context 'when both complete simultaneously (readonly mode)' do
      it 'detects both completions and returns both_complete state' do
        service = CheckInCompletionService.new(check_in)
        service.complete_employee_side!
        service.complete_manager_side!(completed_by: manager_teammate)

        expect(service.completion_detected?).to be true
        expect(service.completion_state).to eq(:both_complete)
        expect(check_in.reload.employee_completed?).to be true
        expect(check_in.manager_completed?).to be true
      end
    end

    context 'when check-in was already completed' do
      before do
        check_in.update!(
          employee_completed_at: Time.current,
          manager_completed_at: Time.current,
          manager_completed_by_teammate: manager_teammate
        )
      end

      it 'does not detect completion' do
        service = CheckInCompletionService.new(check_in)
        # Try to complete again (should be idempotent)
        service.complete_employee_side!

        # Should not detect completion since it was already complete
        expect(service.completion_detected?).to be false
      end
    end
  end

  describe 'PositionCheckIn' do
    let(:check_in) { create(:position_check_in, teammate: employee_teammate, employment_tenure: employment_tenure) }

    context 'when employee completes' do
      it 'detects completion and returns employee_only state' do
        service = CheckInCompletionService.new(check_in)
        service.complete_employee_side!

        expect(service.completion_detected?).to be true
        expect(service.completion_state).to eq(:employee_only)
      end
    end

    context 'when manager completes' do
      it 'detects completion and returns manager_only state' do
        service = CheckInCompletionService.new(check_in)
        service.complete_manager_side!(completed_by: manager)

        expect(service.completion_detected?).to be true
        expect(service.completion_state).to eq(:manager_only)
      end
    end
  end

  describe 'AspirationCheckIn' do
    let(:aspiration) { create(:aspiration, organization: organization) }
    let(:check_in) { create(:aspiration_check_in, teammate: employee_teammate, aspiration: aspiration) }

    context 'when employee completes' do
      it 'detects completion and returns employee_only state' do
        service = CheckInCompletionService.new(check_in)
        service.complete_employee_side!

        expect(service.completion_detected?).to be true
        expect(service.completion_state).to eq(:employee_only)
      end
    end

    context 'when manager completes' do
      it 'detects completion and returns manager_only state' do
        service = CheckInCompletionService.new(check_in)
        service.complete_manager_side!(completed_by: manager)

        expect(service.completion_detected?).to be true
        expect(service.completion_state).to eq(:manager_only)
      end
    end
  end
end

