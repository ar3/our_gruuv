require 'rails_helper'

RSpec.describe CheckInFinalizationService, type: :service do
  let(:organization) { create(:organization, :company) }
  let(:manager) { create(:person) }
  let(:employee) { create(:person) }
  let(:assignment) { create(:assignment, company: organization) }
  
  let!(:manager_teammate) { create(:teammate, person: manager, organization: organization) }
  let!(:employee_teammate) { create(:teammate, person: employee, organization: organization) }
  
  let!(:assignment_tenure) do
    create(:assignment_tenure,
           teammate: employee_teammate,
           assignment: assignment,
           anticipated_energy_percentage: 50,
           started_at: 1.month.ago)
  end
  
  let!(:assignment_check_in) do
    create(:assignment_check_in,
           teammate: employee_teammate,
           assignment: assignment,
           employee_rating: 'meeting',
           manager_rating: 'exceeding',
           employee_completed_at: 1.day.ago,
           manager_completed_at: 1.day.ago)
  end
  
  let!(:employment_tenure) do
    create(:employment_tenure,
           teammate: employee_teammate,
           company: organization,
           manager: manager,
           started_at: 1.month.ago)
  end
  
  let(:finalization_params) do
    {
      assignment_check_ins: {
        assignment_check_in.id => {
          finalize: '1',
          official_rating: 'meeting',
          shared_notes: 'Good work'
        }
      }
    }
  end
  
  let(:request_info) do
    {
      ip_address: '127.0.0.1',
      user_agent: 'Test Agent',
      timestamp: Time.current.iso8601
    }
  end
  
  describe '#call' do
    context 'when maap_snapshot_reason is provided' do
      it 'uses provided reason when creating snapshot' do
        service = described_class.new(
          teammate: employee_teammate,
          finalization_params: finalization_params,
          finalized_by: manager,
          request_info: request_info,
          maap_snapshot_reason: 'Q4 2024 Performance Review'
        )
        
        result = service.call
        
        expect(result.ok?).to be true
        snapshot = MaapSnapshot.last
        expect(snapshot.reason).to eq('Q4 2024 Performance Review')
      end
      
      it 'preserves whitespace in custom reason' do
        custom_reason = '  Q4 2024 Performance Review  '
        service = described_class.new(
          teammate: employee_teammate,
          finalization_params: finalization_params,
          finalized_by: manager,
          request_info: request_info,
          maap_snapshot_reason: custom_reason
        )
        
        result = service.call
        
        expect(result.ok?).to be true
        snapshot = MaapSnapshot.last
        expect(snapshot.reason).to eq(custom_reason)
      end
    end
    
    context 'when maap_snapshot_reason is blank' do
      it 'falls back to default reason when reason is blank' do
        service = described_class.new(
          teammate: employee_teammate,
          finalization_params: finalization_params,
          finalized_by: manager,
          request_info: request_info,
          maap_snapshot_reason: ''
        )
        
        result = service.call
        
        expect(result.ok?).to be true
        snapshot = MaapSnapshot.last
        expect(snapshot.reason).to eq("Check-in finalization for #{employee.display_name}")
      end
    end
    
    context 'when maap_snapshot_reason is nil' do
      it 'falls back to default reason when reason is nil' do
        service = described_class.new(
          teammate: employee_teammate,
          finalization_params: finalization_params,
          finalized_by: manager,
          request_info: request_info,
          maap_snapshot_reason: nil
        )
        
        result = service.call
        
        expect(result.ok?).to be true
        snapshot = MaapSnapshot.last
        expect(snapshot.reason).to eq("Check-in finalization for #{employee.display_name}")
      end
      
      it 'falls back to default reason when reason is not provided' do
        service = described_class.new(
          teammate: employee_teammate,
          finalization_params: finalization_params,
          finalized_by: manager,
          request_info: request_info
        )
        
        result = service.call
        
        expect(result.ok?).to be true
        snapshot = MaapSnapshot.last
        expect(snapshot.reason).to eq("Check-in finalization for #{employee.display_name}")
      end
    end
  end
end

