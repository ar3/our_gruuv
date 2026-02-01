require 'rails_helper'

RSpec.describe UpdateEmploymentTenureService, type: :service do
  let(:company) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { create(:company_teammate, person: person, organization: company) }
  let(:current_manager) { create(:person) }
  let(:current_manager_teammate) { create(:company_teammate, person: current_manager, organization: company) }
  let(:new_manager) { create(:person) }
  let(:new_manager_teammate) { create(:company_teammate, person: new_manager, organization: company) }
  let(:position_major_level) { create(:position_major_level) }
  let(:current_title) { create(:title, company: company, position_major_level: position_major_level, external_title: 'Current Engineer') }
  let(:new_title) { create(:title, company: company, position_major_level: position_major_level, external_title: 'New Engineer') }
  let(:current_position_level) { create(:position_level, position_major_level: position_major_level) }
  let(:new_position_level) { create(:position_level, position_major_level: position_major_level) }
  let(:current_position) { create(:position, title: current_title, position_level: current_position_level) }
  let(:new_position) { create(:position, title: new_title, position_level: new_position_level) }
  let(:created_by) { create(:company_teammate, organization: company) }
  
  # Create seat after position to ensure they match
  let(:current_seat) do
    current_position # Ensure position is created first
    create(:seat, title: current_position.title, seat_needed_by: Date.current + 1.month)
  end
  let(:new_seat) do
    current_position # Ensure position is created first
    create(:seat, title: current_position.title, seat_needed_by: Date.current + 2.months)
  end
  
  let(:current_tenure) do
    # Create position and seat first to ensure they match
    pos = current_position
    # Use a unique date that won't conflict with current_seat or new_seat
    seat = create(:seat, title: pos.title, seat_needed_by: Date.current + 10.months)
    
    # Create employment_tenure directly to avoid factory's after(:build) hook overwriting position
    # Ensure manager_teammate is created
    current_manager_teammate
    EmploymentTenure.create!(
      teammate: teammate,
      company: company,
      position: pos,
      manager_teammate: current_manager_teammate,
      seat: seat,
      employment_type: 'full_time',
      started_at: 6.months.ago
    )
  end

  describe '.call' do
    context 'when manager changes' do
      it 'ends current tenure and creates new tenure with manager change' do
        new_manager_teammate
        params = {
          manager_teammate_id: new_manager_teammate.id,
          position_id: current_position.id,
          employment_type: 'full_time',
          seat_id: current_seat.id
        }

        result = described_class.call(
          teammate: teammate,
          current_tenure: current_tenure,
          params: params,
          created_by: created_by
        )

        expect(result.ok?).to be true
        expect(current_tenure.reload.ended_at).to be_within(1.second).of(Time.current)
        
        new_tenure = EmploymentTenure.where(teammate: teammate, company: company).order(:created_at).last
        expect(new_tenure.manager_teammate).to eq(new_manager_teammate)
        expect(new_tenure.position).to eq(current_position)
        expect(new_tenure.employment_type).to eq('full_time')
        expect(new_tenure.seat).to eq(current_seat)
        expect(new_tenure.started_at).to be_within(1.second).of(Time.current)
        expect(new_tenure.ended_at).to be_nil
      end
      
      it 'creates observable moment for seat change' do
        new_manager_teammate
        params = {
          manager_teammate_id: new_manager_teammate.id,
          position_id: current_position.id,
          employment_type: 'full_time',
          seat_id: current_seat.id
        }

        expect {
          described_class.call(
            teammate: teammate,
            current_tenure: current_tenure,
            params: params,
            created_by: created_by
          )
        }.to change { ObservableMoment.count }.by(1)
        
        moment = ObservableMoment.last
        expect(moment.moment_type).to eq('seat_change')
        expect(moment.primary_potential_observer).to eq(created_by)
        expect(moment.metadata['old_position_id']).to eq(current_position.id)
      end

      it 'creates maap_snapshot with position_tenure change_type' do
        new_manager_teammate
        params = {
          manager_teammate_id: new_manager_teammate.id,
          position_id: current_position.id,
          employment_type: 'full_time',
          seat_id: current_seat.id,
          reason: 'Manager change'
        }

        expect {
          described_class.call(
            teammate: teammate,
            current_tenure: current_tenure,
            params: params,
            created_by: created_by
          )
        }.to change { MaapSnapshot.count }.by(1)

        snapshot = MaapSnapshot.last
        expect(snapshot.change_type).to eq('position_tenure')
        expect(snapshot.employee_company_teammate).to eq(teammate)
        expect(snapshot.creator_company_teammate).to eq(created_by)
        expect(snapshot.company_id).to eq(company.id)
        expect(snapshot.effective_date).to eq(Date.current)
        expect(snapshot.reason).to eq('Manager change')
        expect(snapshot.maap_data['employment_tenure']).to be_present
      end
    end

    context 'when position changes' do
      it 'ends current tenure and creates new tenure with position change' do
        # Create a seat that matches the new position's title
        seat_for_new_position = create(:seat, title: new_title, seat_needed_by: Date.current + 3.months)
        
        params = {
          manager_teammate_id: current_manager_teammate.id,
          position_id: new_position.id,
          employment_type: 'full_time',
          seat_id: seat_for_new_position.id
        }

        result = described_class.call(
          teammate: teammate,
          current_tenure: current_tenure,
          params: params,
          created_by: created_by
        )

        expect(result.ok?).to be true
        expect(current_tenure.reload.ended_at).to be_within(1.second).of(Time.current)
        
        new_tenure = EmploymentTenure.where(teammate: teammate, company: company).order(:created_at).last
        expect(new_tenure.position).to eq(new_position)
        expect(new_tenure.manager_teammate).to eq(current_manager_teammate)
        expect(new_tenure.employment_type).to eq('full_time')
        expect(new_tenure.seat).to eq(seat_for_new_position)
        expect(new_tenure.started_at).to be_within(1.second).of(Time.current)
      end

      it 'creates maap_snapshot' do
        seat_for_new_position = create(:seat, title: new_title, seat_needed_by: Date.current + 4.months)
        
        params = {
          manager_teammate_id: current_manager_teammate.id,
          position_id: new_position.id,
          employment_type: 'full_time',
          seat_id: seat_for_new_position.id
        }

        expect {
          described_class.call(
            teammate: teammate,
            current_tenure: current_tenure,
            params: params,
            created_by: created_by
          )
        }.to change { MaapSnapshot.count }.by(1)
      end

      it 'allows clearing seat when position changes' do
        # Ensure current_tenure has a seat
        expect(current_tenure.seat).to be_present
        
        params = {
          manager_teammate_id: current_manager_teammate.id,
          position_id: new_position.id,
          employment_type: 'full_time',
          seat_id: nil
        }

        result = described_class.call(
          teammate: teammate,
          current_tenure: current_tenure,
          params: params,
          created_by: created_by
        )

        expect(result.ok?).to be true
        expect(current_tenure.reload.ended_at).to be_within(1.second).of(Time.current)
        
        new_tenure = EmploymentTenure.where(teammate: teammate, company: company).order(:created_at).last
        expect(new_tenure.position).to eq(new_position)
        expect(new_tenure.seat).to be_nil
        expect(new_tenure.started_at).to be_within(1.second).of(Time.current)
      end

      it 'allows clearing seat with empty string when position changes' do
        # Ensure current_tenure has a seat
        expect(current_tenure.seat).to be_present
        
        params = {
          manager_teammate_id: current_manager_teammate.id,
          position_id: new_position.id,
          employment_type: 'full_time',
          seat_id: ''
        }

        result = described_class.call(
          teammate: teammate,
          current_tenure: current_tenure,
          params: params,
          created_by: created_by
        )

        expect(result.ok?).to be true
        expect(current_tenure.reload.ended_at).to be_within(1.second).of(Time.current)
        
        new_tenure = EmploymentTenure.where(teammate: teammate, company: company).order(:created_at).last
        expect(new_tenure.position).to eq(new_position)
        expect(new_tenure.seat).to be_nil
        expect(new_tenure.started_at).to be_within(1.second).of(Time.current)
      end
    end

    context 'when employment_type changes' do
      it 'ends current tenure and creates new tenure with employment_type change' do
        params = {
          manager_teammate_id: current_manager_teammate.id,
          position_id: current_position.id,
          employment_type: 'part_time',
          seat_id: current_seat.id
        }

        result = described_class.call(
          teammate: teammate,
          current_tenure: current_tenure,
          params: params,
          created_by: created_by
        )

        expect(result.ok?).to be true
        expect(current_tenure.reload.ended_at).to be_within(1.second).of(Time.current)
        
        new_tenure = EmploymentTenure.where(teammate: teammate, company: company).order(:created_at).last
        expect(new_tenure.employment_type).to eq('part_time')
        expect(new_tenure.manager_teammate).to eq(current_manager_teammate)
        expect(new_tenure.position).to eq(current_position)
        expect(new_tenure.started_at).to be_within(1.second).of(Time.current)
      end

      it 'creates maap_snapshot' do
        params = {
          manager_teammate_id: current_manager_teammate.id,
          position_id: current_position.id,
          employment_type: 'part_time',
          seat_id: current_seat.id
        }

        expect {
          described_class.call(
            teammate: teammate,
            current_tenure: current_tenure,
            params: params,
            created_by: created_by
          )
        }.to change { MaapSnapshot.count }.by(1)
      end
    end

    context 'when termination_date is provided' do
      it 'updates active tenure ended_at without creating new tenure' do
        termination_date = Date.current + 1.week
        params = {
          manager_teammate_id: current_manager_teammate.id,
          position_id: current_position.id,
          employment_type: 'full_time',
          seat_id: current_seat.id,
          termination_date: termination_date
        }

        result = described_class.call(
          teammate: teammate,
          current_tenure: current_tenure,
          params: params,
          created_by: created_by
        )

        expect(result.ok?).to be true
        expect(current_tenure.reload.ended_at).to eq(termination_date.to_time)
        expect(EmploymentTenure.where(teammate: teammate, company: company).count).to eq(1)
      end

      it 'creates maap_snapshot with effective_date set to termination_date' do
        termination_date = Date.current + 1.week
        params = {
          manager_teammate_id: current_manager_teammate.id,
          position_id: current_position.id,
          employment_type: 'full_time',
          seat_id: current_seat.id,
          termination_date: termination_date,
          reason: 'Termination'
        }

        expect {
          described_class.call(
            teammate: teammate,
            current_tenure: current_tenure,
            params: params,
            created_by: created_by
          )
        }.to change { MaapSnapshot.count }.by(1)

        snapshot = MaapSnapshot.last
        expect(snapshot.effective_date).to eq(termination_date)
        expect(snapshot.reason).to eq('Termination')
      end
    end

    context 'when only seat changes' do
      it 'updates tenure in place without creating new tenure' do
        params = {
          manager_teammate_id: current_manager_teammate.id,
          position_id: current_position.id,
          employment_type: 'full_time',
          seat_id: new_seat.id
        }

        result = described_class.call(
          teammate: teammate,
          current_tenure: current_tenure,
          params: params,
          created_by: created_by
        )

        expect(result.ok?).to be true
        expect(current_tenure.reload.seat).to eq(new_seat)
        expect(current_tenure.ended_at).to be_nil
        expect(EmploymentTenure.where(teammate: teammate, company: company).count).to eq(1)
      end

      it 'does not create maap_snapshot' do
        params = {
          manager_teammate_id: current_manager_teammate.id,
          position_id: current_position.id,
          employment_type: 'full_time',
          seat_id: new_seat.id
        }

        expect {
          described_class.call(
            teammate: teammate,
            current_tenure: current_tenure,
            params: params,
            created_by: created_by
          )
        }.not_to change { MaapSnapshot.count }
      end

      it 'clears seat when seat_id is set to nil' do
        # Ensure current_tenure has a seat
        expect(current_tenure.seat).to be_present
        
        params = {
          manager_teammate_id: current_manager_teammate.id,
          position_id: current_position.id,
          employment_type: 'full_time',
          seat_id: nil
        }

        result = described_class.call(
          teammate: teammate,
          current_tenure: current_tenure,
          params: params,
          created_by: created_by
        )

        expect(result.ok?).to be true
        expect(current_tenure.reload.seat).to be_nil
        expect(current_tenure.ended_at).to be_nil
        expect(EmploymentTenure.where(teammate: teammate, company: company).count).to eq(1)
      end

      it 'clears seat when seat_id is set to empty string' do
        # Ensure current_tenure has a seat
        expect(current_tenure.seat).to be_present
        
        params = {
          manager_teammate_id: current_manager_teammate.id,
          position_id: current_position.id,
          employment_type: 'full_time',
          seat_id: ''
        }

        result = described_class.call(
          teammate: teammate,
          current_tenure: current_tenure,
          params: params,
          created_by: created_by
        )

        expect(result.ok?).to be true
        expect(current_tenure.reload.seat).to be_nil
        expect(current_tenure.ended_at).to be_nil
        expect(EmploymentTenure.where(teammate: teammate, company: company).count).to eq(1)
      end
    end

    context 'when multiple changes occur' do
      it 'handles manager and position change together' do
        new_manager_teammate
        seat_for_new_position = create(:seat, title: new_title, seat_needed_by: Date.current + 5.months)
        
        params = {
          manager_teammate_id: new_manager_teammate.id,
          position_id: new_position.id,
          employment_type: 'full_time',
          seat_id: seat_for_new_position.id
        }

        result = described_class.call(
          teammate: teammate,
          current_tenure: current_tenure,
          params: params,
          created_by: created_by
        )

        expect(result.ok?).to be true
        expect(current_tenure.reload.ended_at).to be_within(1.second).of(Time.current)
        
        new_tenure = EmploymentTenure.where(teammate: teammate, company: company).order(:created_at).last
        expect(new_tenure.manager_teammate).to eq(new_manager_teammate)
        expect(new_tenure.position).to eq(new_position)
        expect(new_tenure.seat).to eq(seat_for_new_position)
        expect(new_tenure.started_at).to be_within(1.second).of(Time.current)
      end

      it 'creates maap_snapshot for multiple changes' do
        new_manager_teammate
        seat_for_new_position = create(:seat, title: new_title, seat_needed_by: Date.current + 6.months)
        
        params = {
          manager_teammate_id: new_manager_teammate.id,
          position_id: new_position.id,
          employment_type: 'part_time',
          seat_id: seat_for_new_position.id
        }

        expect {
          described_class.call(
            teammate: teammate,
            current_tenure: current_tenure,
            params: params,
            created_by: created_by
          )
        }.to change { MaapSnapshot.count }.by(1)
      end
    end

    context 'when no changes are made' do
      it 'does not create new tenure' do
        # Use the actual values from current_tenure
        params = {
          manager_teammate_id: current_tenure.manager_teammate_id,
          position_id: current_tenure.position_id,
          employment_type: current_tenure.employment_type,
          seat_id: current_tenure.seat_id
        }

        expect {
          described_class.call(
            teammate: teammate,
            current_tenure: current_tenure,
            params: params,
            created_by: created_by
          )
        }.not_to change { EmploymentTenure.count }
      end

      it 'does not create maap_snapshot' do
        # Use the actual values from current_tenure
        params = {
          manager_teammate_id: current_tenure.manager_teammate_id,
          position_id: current_tenure.position_id,
          employment_type: current_tenure.employment_type,
          seat_id: current_tenure.seat_id
        }

        expect {
          described_class.call(
            teammate: teammate,
            current_tenure: current_tenure,
            params: params,
            created_by: created_by
          )
        }.not_to change { MaapSnapshot.count }
      end
    end

    context 'when termination_date and other changes occur' do
      it 'updates ended_at and does not create new tenure (termination takes precedence)' do
        new_manager_teammate
        termination_date = Date.current + 1.week
        params = {
          manager_teammate_id: new_manager_teammate.id,
          position_id: current_position.id,
          employment_type: 'full_time',
          seat_id: current_seat.id,
          termination_date: termination_date
        }

        result = described_class.call(
          teammate: teammate,
          current_tenure: current_tenure,
          params: params,
          created_by: created_by
        )

        expect(result.ok?).to be true
        expect(current_tenure.reload.ended_at).to eq(termination_date.to_time)
        
        # When termination_date is provided, we update the current tenure, not create new one
        expect(EmploymentTenure.where(teammate: teammate, company: company).count).to eq(1)
      end

      it 'creates maap_snapshot when termination_date and other changes occur' do
        new_manager_teammate
        termination_date = Date.current + 1.week
        params = {
          manager_teammate_id: new_manager_teammate.id,
          position_id: current_position.id,
          employment_type: 'full_time',
          seat_id: current_seat.id,
          termination_date: termination_date
        }

        expect {
          described_class.call(
            teammate: teammate,
            current_tenure: current_tenure,
            params: params,
            created_by: created_by
          )
        }.to change { MaapSnapshot.count }.by(1)
      end
    end

    context 'error handling' do
      it 'returns error when tenure update fails' do
        invalid_record = current_tenure.dup
        invalid_record.errors.add(:base, 'Test validation error')
        allow(current_tenure).to receive(:update!).and_raise(ActiveRecord::RecordInvalid.new(invalid_record))
        
        params = {
          manager_teammate_id: current_manager_teammate.id,
          position_id: current_position.id,
          employment_type: 'full_time',
          seat_id: current_seat.id,
          termination_date: Date.current
        }

        result = described_class.call(
          teammate: teammate,
          current_tenure: current_tenure,
          params: params,
          created_by: created_by
        )

        expect(result.ok?).to be false
        expect(result.error).to be_present
      end

      it 'returns error when new tenure creation fails' do
        # Ensure current_tenure is created before mocking
        current_tenure
        
        invalid_record = EmploymentTenure.new
        invalid_record.errors.add(:base, 'Test validation error')
        # Mock only new instances, not existing ones
        allow(EmploymentTenure).to receive(:new).and_call_original
        allow_any_instance_of(EmploymentTenure).to receive(:save!).and_raise(ActiveRecord::RecordInvalid.new(invalid_record))
        
        new_manager_teammate
        params = {
          manager_teammate_id: new_manager_teammate.id,
          position_id: current_position.id,
          employment_type: 'full_time',
          seat_id: current_seat.id
        }

        result = described_class.call(
          teammate: teammate,
          current_tenure: current_tenure,
          params: params,
          created_by: created_by
        )

        expect(result.ok?).to be false
        expect(result.error).to be_present
      end
    end

    context 'when copying tenure attributes' do
      it 'copies all attributes from previous tenure except changed ones' do
        # Set up tenure with various attributes
        current_tenure.update!(
          employment_type: 'contract',
          official_position_rating: 2
        )

        new_manager_teammate
        params = {
          manager_teammate_id: new_manager_teammate.id,
          position_id: current_position.id,
          employment_type: 'contract', # Same
          seat_id: current_seat.id
        }

        result = described_class.call(
          teammate: teammate,
          current_tenure: current_tenure,
          params: params,
          created_by: created_by
        )

        expect(result.ok?).to be true
        
        new_tenure = EmploymentTenure.where(teammate: teammate, company: company).order(:created_at).last
        expect(new_tenure.employment_type).to eq('contract')
        expect(new_tenure.official_position_rating).to eq(2)
        expect(new_tenure.manager_teammate).to eq(new_manager_teammate) # Changed
      end
    end
  end
end

