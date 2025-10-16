require 'rails_helper'

RSpec.describe CheckInFinalizationService do
  let(:organization) { create(:organization) }
  let(:manager) { create(:person) }
  let(:employee) { create(:person) }
  let(:manager_teammate) { create(:teammate, person: manager, organization: organization) }
  let(:employee_teammate) { create(:teammate, person: employee, organization: organization) }
  let(:assignment1) { create(:assignment, company: organization, title: 'Frontend Development') }
  let(:assignment2) { create(:assignment, company: organization, title: 'Backend Development') }
  
  let!(:assignment_tenure1) do
    create(:assignment_tenure,
           teammate: employee_teammate,
           assignment: assignment1,
           anticipated_energy_percentage: 60,
           started_at: 1.month.ago)
  end
  
  let!(:assignment_tenure2) do
    create(:assignment_tenure,
           teammate: employee_teammate,
           assignment: assignment2,
           anticipated_energy_percentage: 40,
           started_at: 1.month.ago)
  end
  
  let!(:assignment_check_in1) do
    create(:assignment_check_in,
           teammate: employee_teammate,
           assignment: assignment1,
           employee_rating: 'exceeding',
           manager_rating: 'meeting',
           employee_completed_at: 1.day.ago,
           manager_completed_at: 1.day.ago)
  end
  
  let!(:assignment_check_in2) do
    create(:assignment_check_in,
           teammate: employee_teammate,
           assignment: assignment2,
           employee_rating: 'meeting',
           manager_rating: 'working_to_meet',
           employee_completed_at: 1.day.ago,
           manager_completed_at: 1.day.ago)
  end
  
  let(:finalization_params) do
    {
      finalize_assignments: '1',
      assignment_check_ins: {
        assignment_check_in1.id => {
          assignment_id: assignment1.id,
          official_rating: 'meeting',
          shared_notes: 'Good work on frontend'
        },
        assignment_check_in2.id => {
          assignment_id: assignment2.id,
          official_rating: 'working_to_meet',
          shared_notes: 'Needs improvement on backend'
        }
      }
    }
  end
  
  let(:service) do
    described_class.new(
      teammate: employee_teammate,
      finalization_params: finalization_params,
      finalized_by: manager,
      request_info: { ip: '127.0.0.1' }
    )
  end

  describe '#call' do
    context 'when finalizing multiple assignment check-ins' do
      it 'successfully finalizes all assignment check-ins in single transaction' do
        result = service.call
        
        expect(result).to be_ok
        expect(result.value[:results][:assignments]).to be_an(Array)
        expect(result.value[:results][:assignments].length).to eq(2)
      end
      
      it 'creates single snapshot with all assignment data' do
        expect { service.call }
          .to change { MaapSnapshot.count }
          .by(1)
        
        snapshot = MaapSnapshot.last
        expect(snapshot.employee).to eq(employee)
        expect(snapshot.change_type).to eq('assignment_management')
        expect(snapshot.maap_data['assignments']).to be_present
      end
      
      it 'links snapshot to all finalized check-ins' do
        result = service.call
        
        snapshot = result.value[:snapshot]
        assignment_results = result.value[:results][:assignments]
        
        assignment_results.each do |assignment_result|
          check_in = assignment_result[:check_in]
          expect(check_in.maap_snapshot).to eq(snapshot)
        end
      end
      
      it 'closes old tenures and creates new ones' do
        expect { service.call }
          .to change { AssignmentTenure.count }
          .by(2) # Creates 2 new tenures
        
        # Old tenures should be closed
        expect(assignment_tenure1.reload.ended_at).to eq(Date.current)
        expect(assignment_tenure2.reload.ended_at).to eq(Date.current)
        
        # New tenures should be created
        new_tenures = AssignmentTenure.where(ended_at: nil).where.not(id: [assignment_tenure1.id, assignment_tenure2.id])
        expect(new_tenures.count).to eq(2)
      end
      
      it 'updates check-ins with official data' do
        service.call
        
        assignment_check_in1.reload
        assignment_check_in2.reload
        
        expect(assignment_check_in1.official_rating).to eq('meeting')
        expect(assignment_check_in1.shared_notes).to eq('Good work on frontend')
        expect(assignment_check_in1.official_check_in_completed_at).to be_present
        
        expect(assignment_check_in2.official_rating).to eq('working_to_meet')
        expect(assignment_check_in2.shared_notes).to eq('Needs improvement on backend')
        expect(assignment_check_in2.official_check_in_completed_at).to be_present
      end
    end
    
    context 'when finalizing mixed check-ins (position + assignments)' do
      let!(:position_check_in) do
        create(:position_check_in,
               teammate: employee_teammate,
               employee_rating: 2,
               manager_rating: 1,
               employee_completed_at: 1.day.ago,
               manager_completed_at: 1.day.ago)
      end
      
      let(:mixed_params) do
        finalization_params.merge(
          finalize_position: '1',
          position_official_rating: 1,
          position_shared_notes: 'Position notes'
        )
      end
      
      let(:mixed_service) do
        described_class.new(
          teammate: employee_teammate,
          finalization_params: mixed_params,
          finalized_by: manager,
          request_info: { ip: '127.0.0.1' }
        )
      end
      
      it 'handles both position and assignment finalization' do
        result = mixed_service.call
        
        expect(result).to be_ok
        expect(result.value[:results]).to include(:position, :assignments)
        expect(result.value[:results][:assignments].length).to eq(2)
      end
    end
    
    context 'when assignment finalization fails' do
      before do
        allow_any_instance_of(Finalizers::AssignmentCheckInFinalizer)
          .to receive(:finalize)
          .and_return(Result.err('Assignment finalization failed'))
      end
      
      it 'rolls back transaction' do
        expect { service.call }
          .not_to change { AssignmentTenure.count }
        
        expect(assignment_tenure1.reload.ended_at).to be_nil
        expect(assignment_tenure2.reload.ended_at).to be_nil
      end
      
      it 'returns error result' do
        result = service.call
        
        expect(result.ok?).to be false
        expect(result.error).to include('Assignment finalization failed')
      end
    end
    
    context 'when no assignments to finalize' do
      let(:empty_params) do
        {
          finalize_assignments: '1',
          assignment_check_ins: {}
        }
      end
      
      let(:empty_service) do
        described_class.new(
          teammate: employee_teammate,
          finalization_params: empty_params,
          finalized_by: manager,
          request_info: { ip: '127.0.0.1' }
        )
      end
      
      it 'succeeds with empty assignments array' do
        result = empty_service.call
        
        expect(result).to be_ok
        expect(result.value[:results][:assignments]).to eq([])
      end
    end
  end
end