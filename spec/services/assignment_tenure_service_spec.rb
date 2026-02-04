require 'rails_helper'

RSpec.describe AssignmentTenureService, type: :service do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, person: person, organization: organization) }
  let(:assignment) { create(:assignment, company: organization) }
  let(:created_by) { create(:person) }
  let(:service) { described_class.new(person: person, assignment: assignment, created_by: created_by) }

  describe '#update_tenure' do
    context 'when setting energy to 0%' do
      it 'ends the active tenure' do
        active_tenure = create(:assignment_tenure, 
          teammate: teammate, 
          assignment: assignment, 
          anticipated_energy_percentage: 50,
          started_at: 1.month.ago,
          ended_at: nil)

        service.update_tenure(
          anticipated_energy_percentage: 0,
          started_at: Date.current
        )

        active_tenure.reload
        expect(active_tenure.ended_at).to be_present
      end

      it 'does nothing if no active tenure exists' do
        expect {
          service.update_tenure(
            anticipated_energy_percentage: 0,
            started_at: Date.current
          )
        }.not_to change { AssignmentTenure.count }
      end
    end

    context 'when energy changes from existing tenure' do
      let!(:active_tenure) do
        create(:assignment_tenure,
          teammate: teammate,
          assignment: assignment,
          anticipated_energy_percentage: 25,
          started_at: 1.month.ago,
          ended_at: nil)
      end

      it 'ends current tenure and creates new one' do
        new_start_date = Date.current + 1.week

        expect {
          service.update_tenure(
            anticipated_energy_percentage: 75,
            started_at: new_start_date
          )
        }.to change { AssignmentTenure.count }.by(1)

        # Check old tenure was ended
        active_tenure.reload
        expect(active_tenure.ended_at.to_date).to eq(new_start_date)

        # Check new tenure was created
        new_tenure = AssignmentTenure.where(company_teammate: teammate, assignment: assignment).active.first
        expect(new_tenure.anticipated_energy_percentage).to eq(75)
        expect(new_tenure.started_at).to eq(new_start_date)
      end

      it 'allows same-day transitions' do
        same_day = Date.current

        expect {
          service.update_tenure(
            anticipated_energy_percentage: 75,
            started_at: same_day
          )
        }.to change { AssignmentTenure.count }.by(1)

        # Old tenure should end on the same day
        active_tenure.reload
        expect(active_tenure.ended_at.to_date).to eq(same_day)

        # New tenure should start on the same day
        new_tenure = AssignmentTenure.where(company_teammate: teammate, assignment: assignment).active.first
        expect(new_tenure.started_at).to eq(same_day)
      end
    end

    context 'when energy is the same as existing tenure' do
      let!(:active_tenure) do
        create(:assignment_tenure,
          teammate: teammate,
          assignment: assignment,
          anticipated_energy_percentage: 50,
          started_at: 1.month.ago,
          ended_at: nil)
      end

      it 'does not create a new tenure' do
        expect {
          service.update_tenure(
            anticipated_energy_percentage: 50,
            started_at: Date.current
          )
        }.not_to change { AssignmentTenure.count }

        # Original tenure should still be active
        expect(active_tenure.reload.ended_at).to be_nil
      end
    end

    context 'when no active tenure exists' do
      it 'creates a new tenure' do
        start_date = Date.current
        
        # Ensure teammate exists
        teammate

        expect {
          service.update_tenure(
            anticipated_energy_percentage: 30,
            started_at: start_date
          )
        }.to change { AssignmentTenure.count }.by(1)

        new_tenure = AssignmentTenure.where(company_teammate: teammate, assignment: assignment).active.first
        expect(new_tenure.anticipated_energy_percentage).to eq(30)
        expect(new_tenure.started_at).to eq(start_date)
      end
    end

    context 'validation errors' do
      it 'raises error for invalid energy percentage' do
        expect {
          service.update_tenure(
            anticipated_energy_percentage: 150,
            started_at: Date.current
          )
        }.to raise_error(AssignmentTenureService::TenureLifecycleError, "Anticipated energy must be between 0 and 100")
      end

      it 'raises error for invalid start date' do
        expect {
          service.update_tenure(
            anticipated_energy_percentage: 50,
            started_at: 'invalid-date'
          )
        }.to raise_error(AssignmentTenureService::TenureLifecycleError, /Started at must be a valid date/)
      end

      it 'raises error for nil person' do
        service = described_class.new(person: nil, assignment: assignment, created_by: created_by)
        
        expect {
          service.update_tenure(
            anticipated_energy_percentage: 50,
            started_at: Date.current
          )
        }.to raise_error(AssignmentTenureService::TenureLifecycleError, "Person cannot be nil")
      end

      it 'raises error for nil assignment' do
        service = described_class.new(person: person, assignment: nil, created_by: created_by)
        
        expect {
          service.update_tenure(
            anticipated_energy_percentage: 50,
            started_at: Date.current
          )
        }.to raise_error(AssignmentTenureService::TenureLifecycleError, "Assignment cannot be nil")
      end
    end

    context 'edge cases' do
      it 'handles end date being in the past' do
        active_tenure = create(:assignment_tenure,
          teammate: teammate,
          assignment: assignment,
          anticipated_energy_percentage: 25,
          started_at: 1.month.ago,
          ended_at: nil)

        past_start_date = Date.current - 1.week

        service.update_tenure(
          anticipated_energy_percentage: 75,
          started_at: past_start_date
        )

        # Should end the tenure on the same day as the start date
        active_tenure.reload
        expect(active_tenure.ended_at.to_date).to eq(past_start_date)
      end

      it 'handles multiple tenures for same person and assignment' do
        # Create an old ended tenure
        old_tenure = create(:assignment_tenure,
          teammate: teammate,
          assignment: assignment,
          anticipated_energy_percentage: 25,
          started_at: 2.months.ago,
          ended_at: 1.month.ago)

        # Create current active tenure
        active_tenure = create(:assignment_tenure,
          teammate: teammate,
          assignment: assignment,
          anticipated_energy_percentage: 50,
          started_at: 1.month.ago,
          ended_at: nil)

        service.update_tenure(
          anticipated_energy_percentage: 75,
          started_at: Date.current
        )

        # Only the active tenure should be affected
        old_tenure.reload
        expect(old_tenure.ended_at.to_date).to eq(1.month.ago.to_date) # Unchanged

        active_tenure.reload
        expect(active_tenure.ended_at.to_date).to eq(Date.current) # Ended
      end
    end
  end
end
