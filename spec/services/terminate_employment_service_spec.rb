require 'rails_helper'

RSpec.describe TerminateEmploymentService, type: :service do
  let(:company) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { create(:company_teammate, person: person, organization: company, first_employed_at: 1.year.ago) }
  let(:manager) { create(:person) }
  let(:manager_teammate) { create(:company_teammate, person: manager, organization: company) }
  let(:position_major_level) { create(:position_major_level) }
  let(:title) { create(:title, company: company, position_major_level: position_major_level) }
  let(:position_level) { create(:position_level, position_major_level: position_major_level) }
  let(:position) { create(:position, title: title, position_level: position_level) }
  let(:seat) { create(:seat, title: title, seat_needed_by: Date.current + 1.month) }
  let(:created_by) { manager_teammate }
  
  let(:current_tenure) do
    EmploymentTenure.create!(
      teammate: teammate,
      company: company,
      position: position,
      manager_teammate: manager_teammate,
      seat: seat,
      employment_type: 'full_time',
      started_at: 6.months.ago
    )
  end

  describe '.call' do
    context 'with valid termination date' do
      let(:termination_date) { Date.current + 1.week }

      it 'updates employment tenure ended_at' do
        result = described_class.call(
          teammate: teammate,
          current_tenure: current_tenure,
          termination_date: termination_date,
          created_by: created_by
        )

        expect(result.ok?).to be true
        expect(current_tenure.reload.ended_at.to_date).to eq(termination_date)
      end

      it 'updates company teammate last_terminated_at' do
        expect(teammate.last_terminated_at).to be_nil

        result = described_class.call(
          teammate: teammate,
          current_tenure: current_tenure,
          termination_date: termination_date,
          created_by: created_by
        )

        expect(result.ok?).to be true
        expect(teammate.reload.last_terminated_at).to eq(termination_date)
      end

      it 'sets both dates to the same value' do
        result = described_class.call(
          teammate: teammate,
          current_tenure: current_tenure,
          termination_date: termination_date,
          created_by: created_by
        )

        expect(result.ok?).to be true
        expect(current_tenure.reload.ended_at.to_date).to eq(termination_date)
        expect(teammate.reload.last_terminated_at).to eq(termination_date)
        expect(current_tenure.ended_at.to_date).to eq(teammate.last_terminated_at)
      end

      it 'creates a MAAP snapshot' do
        expect {
          described_class.call(
            teammate: teammate,
            current_tenure: current_tenure,
            termination_date: termination_date,
            created_by: created_by
          )
        }.to change { MaapSnapshot.count }.by(1)

        snapshot = MaapSnapshot.last
        expect(snapshot.change_type).to eq('position_tenure')
        expect(snapshot.employee_company_teammate).to eq(teammate)
        expect(snapshot.company_id).to eq(company.id)
        expect(snapshot.effective_date).to eq(termination_date)
        expect(snapshot.reason).to eq('Employment termination')
      end

      it 'uses custom reason when provided' do
        custom_reason = 'Voluntary resignation'
        
        described_class.call(
          teammate: teammate,
          current_tenure: current_tenure,
          termination_date: termination_date,
          created_by: created_by,
          reason: custom_reason
        )

        snapshot = MaapSnapshot.last
        expect(snapshot.reason).to eq(custom_reason)
      end

      it 'handles termination_date as string' do
        termination_date_str = (Date.current + 1.week).strftime('%Y-%m-%d')
        
        result = described_class.call(
          teammate: teammate,
          current_tenure: current_tenure,
          termination_date: termination_date_str,
          created_by: created_by
        )

        expect(result.ok?).to be true
        expect(current_tenure.reload.ended_at.to_date).to eq(Date.parse(termination_date_str))
        expect(teammate.reload.last_terminated_at).to eq(Date.parse(termination_date_str))
      end

      it 'handles termination_date as Time' do
        termination_time = (Date.current + 1.week).to_time
        
        result = described_class.call(
          teammate: teammate,
          current_tenure: current_tenure,
          termination_date: termination_time,
          created_by: created_by
        )

        expect(result.ok?).to be true
        expect(current_tenure.reload.ended_at.to_date).to eq(termination_time.to_date)
        expect(teammate.reload.last_terminated_at).to eq(termination_time.to_date)
      end
    end

    context 'with invalid termination date' do
      it 'returns error for invalid date string' do
        result = described_class.call(
          teammate: teammate,
          current_tenure: current_tenure,
          termination_date: 'invalid-date',
          created_by: created_by
        )

        expect(result.ok?).to be false
        expect(result.error).to include('Failed to terminate employment')
      end
    end

    context 'when teammate is not a CompanyTeammate' do
      let(:department) { create(:department, company: company) }
      let(:dept_teammate) { create(:company_teammate, person: person, organization: company) }
      let(:dept_tenure) do
        EmploymentTenure.create!(
          teammate: dept_teammate,
          company: company,
          position: position,
          employment_type: 'full_time',
          started_at: 6.months.ago
        )
      end

      it 'still updates last_terminated_at if teammate has that field' do
        termination_date = Date.current + 1.week
        
        # Ensure dept_teammate has first_employed_at set
        dept_teammate.update!(first_employed_at: 1.year.ago)
        
        result = described_class.call(
          teammate: dept_teammate,
          current_tenure: dept_tenure,
          termination_date: termination_date,
          created_by: created_by
        )

        puts "DEBUG: result.ok?=#{result.ok?}, error=#{result.error}" unless result.ok?
        expect(result.ok?).to be true
        expect(dept_teammate.reload.last_terminated_at).to eq(termination_date)
      end
    end

    context 'transaction rollback' do
      let(:termination_date) { Date.current + 1.week }

      it 'rolls back both updates if one fails' do
        # Make teammate invalid to cause a failure
        allow(teammate).to receive(:update!).and_raise(ActiveRecord::RecordInvalid.new(teammate))
        
        expect {
          described_class.call(
            teammate: teammate,
            current_tenure: current_tenure,
            termination_date: termination_date,
            created_by: created_by
          )
        }.not_to change { current_tenure.reload.ended_at }
        
        expect(teammate.reload.last_terminated_at).to be_nil
      end
    end
  end
end

