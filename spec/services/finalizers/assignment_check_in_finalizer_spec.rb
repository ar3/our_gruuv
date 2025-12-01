require 'rails_helper'

RSpec.describe Finalizers::AssignmentCheckInFinalizer do
  let(:organization) { create(:organization) }
  let(:manager) { create(:person) }
  let(:employee) { create(:person) }
  let(:manager_teammate) { create(:teammate, person: manager, organization: organization) }
  let(:employee_teammate) { create(:teammate, person: employee, organization: organization) }
  let(:assignment) { create(:assignment, company: organization) }
  
  let!(:assignment_tenure) do
    create(:assignment_tenure,
           teammate: employee_teammate,
           assignment: assignment,
           anticipated_energy_percentage: 75,
           started_at: 1.month.ago)
  end
  
  let!(:assignment_check_in) do
    create(:assignment_check_in,
           teammate: employee_teammate,
           assignment: assignment,
           employee_rating: 'exceeding',
           manager_rating: 'meeting',
           employee_completed_at: 1.day.ago,
           manager_completed_at: 1.day.ago)
  end
  
  let(:finalizer) do
    described_class.new(
      check_in: assignment_check_in,
      official_rating: 'meeting',
      shared_notes: 'Great work on this assignment',
      anticipated_energy_percentage: 80,
      finalized_by: manager
    )
  end

  describe '#finalize' do
    context 'when check-in is ready for finalization' do
      it 'successfully finalizes the assignment check-in' do
        result = finalizer.finalize
        
        expect(result).to be_ok
        expect(result.value).to include(:check_in, :new_tenure, :rating_data)
      end
      
      it 'closes the old tenure with official_rating' do
        expect { finalizer.finalize }
          .to change { assignment_tenure.reload.ended_at }
          .from(nil)
          .to(Date.current)
        
        expect(assignment_tenure.reload.official_rating).to eq('meeting')
      end
      
      it 'creates a new tenure with same assignment and uses provided anticipated_energy_percentage' do
        expect { finalizer.finalize }
          .to change { AssignmentTenure.count }
          .by(1)
        
        new_tenure = AssignmentTenure.last
        expect(new_tenure.assignment).to eq(assignment)
        expect(new_tenure.teammate).to be_a(Teammate)
        expect(new_tenure.teammate.id).to eq(employee_teammate.id)
        expect(new_tenure.anticipated_energy_percentage).to eq(80)
        expect(new_tenure.started_at).to eq(Date.current)
        expect(new_tenure.ended_at).to be_nil
        expect(new_tenure.official_rating).to be_nil
      end
      
      it 'falls back to old tenure anticipated_energy_percentage when provided value is nil' do
        finalizer_with_nil = described_class.new(
          check_in: assignment_check_in,
          official_rating: 'meeting',
          shared_notes: 'Great work',
          anticipated_energy_percentage: nil,
          finalized_by: manager
        )
        
        expect { finalizer_with_nil.finalize }
          .to change { AssignmentTenure.count }
          .by(1)
        
        new_tenure = AssignmentTenure.last
        expect(new_tenure.anticipated_energy_percentage).to eq(75)
      end
      
      it 'falls back to old tenure anticipated_energy_percentage when provided value is empty string' do
        finalizer_with_empty = described_class.new(
          check_in: assignment_check_in,
          official_rating: 'meeting',
          shared_notes: 'Great work',
          anticipated_energy_percentage: '',
          finalized_by: manager
        )
        
        expect { finalizer_with_empty.finalize }
          .to change { AssignmentTenure.count }
          .by(1)
        
        new_tenure = AssignmentTenure.last
        expect(new_tenure.anticipated_energy_percentage).to eq(75)
      end
      
      it 'updates the check-in with official data' do
        finalizer.finalize
        
        assignment_check_in.reload
        expect(assignment_check_in.official_rating).to eq('meeting')
        expect(assignment_check_in.shared_notes).to eq('Great work on this assignment')
        expect(assignment_check_in.official_check_in_completed_at).to be_present
        expect(assignment_check_in.finalized_by).to eq(manager)
      end
      
      it 'returns Result.ok with correct data structure' do
        result = finalizer.finalize
        
        expect(result).to be_ok
        data = result.value
        
        expect(data[:check_in]).to eq(assignment_check_in)
        expect(data[:new_tenure]).to be_a(AssignmentTenure)
      expect(data[:rating_data]).to include(
        assignment_id: assignment.id,
        official_rating: 'meeting',
        rated_at: Time.current.to_s
      )
      end
    end
    
    context 'when check-in is not ready for finalization' do
      before do
        assignment_check_in.update!(
          employee_completed_at: nil,
          manager_completed_at: nil
        )
      end
      
      it 'fails with error message' do
        result = finalizer.finalize
        
        expect(result.ok?).to be false
        expect(result.error).to include('not ready')
      end
    end
    
    context 'when official_rating is nil' do
      let(:finalizer) do
        described_class.new(
          check_in: assignment_check_in,
          official_rating: nil,
          shared_notes: 'Notes',
          anticipated_energy_percentage: 50,
          finalized_by: manager
        )
      end
      
      it 'fails with error message' do
        result = finalizer.finalize
        
        expect(result.ok?).to be false
        expect(result.error).to include('required')
      end
    end
    
    context 'when no active tenure exists' do
      before do
        assignment_tenure.update!(ended_at: 1.day.ago)
      end
      
      it 'fails gracefully' do
        result = finalizer.finalize
        
        expect(result.ok?).to be false
        expect(result.error).to include('No active tenure')
      end
    end
  end
end