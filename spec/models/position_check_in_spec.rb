require 'rails_helper'

RSpec.describe PositionCheckIn, type: :model do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, person: person, organization: organization) }
  let!(:employment_tenure) do
    create(:employment_tenure,
           teammate: teammate,
           company: organization,
           started_at: 1.year.ago)
  end
  let(:check_in) { create(:position_check_in, teammate: teammate, employment_tenure: employment_tenure) }

  describe 'CheckInBehavior integration' do
    it 'includes CheckInBehavior concern' do
      expect(PositionCheckIn.ancestors).to include(CheckInBehavior)
    end

    it 'has required associations from CheckInBehavior' do
      expect(check_in).to respond_to(:teammate)
      expect(check_in).to respond_to(:finalized_by)
      expect(check_in).to respond_to(:maap_snapshot)
    end

    it 'has common scopes from CheckInBehavior' do
      expect(PositionCheckIn).to respond_to(:recent)
      expect(PositionCheckIn).to respond_to(:for_teammate)
      expect(PositionCheckIn).to respond_to(:open)
      expect(PositionCheckIn).to respond_to(:closed)
      expect(PositionCheckIn).to respond_to(:employee_completed)
      expect(PositionCheckIn).to respond_to(:manager_completed)
      expect(PositionCheckIn).to respond_to(:ready_for_finalization)
    end

    it 'has status methods from CheckInBehavior' do
      expect(check_in).to respond_to(:open?)
      expect(check_in).to respond_to(:closed?)
      expect(check_in).to respond_to(:employee_completed?)
      expect(check_in).to respond_to(:manager_completed?)
      expect(check_in).to respond_to(:officially_completed?)
      expect(check_in).to respond_to(:ready_for_finalization?)
    end

    it 'has completion actions from CheckInBehavior' do
      expect(check_in).to respond_to(:complete_employee_side!)
      expect(check_in).to respond_to(:complete_manager_side!)
      expect(check_in).to respond_to(:uncomplete_employee_side!)
      expect(check_in).to respond_to(:uncomplete_manager_side!)
    end
  end

  describe 'Position-specific functionality' do
    it 'belongs to employment tenure' do
      expect(check_in.employment_tenure).to eq(employment_tenure)
    end

    it 'has position-specific rating validations' do
      expect(check_in).to allow_value(-3).for(:employee_rating)
      expect(check_in).to allow_value(0).for(:employee_rating)
      expect(check_in).to allow_value(3).for(:employee_rating)
      expect(check_in).to_not allow_value(-4).for(:employee_rating)
      expect(check_in).to_not allow_value(4).for(:employee_rating)
    end
  end

  describe 'find_or_create_open_for' do
    it 'creates new check-in when none exists' do
      expect {
        PositionCheckIn.find_or_create_open_for(teammate)
      }.to change(PositionCheckIn, :count).by(1)
    end

    it 'returns existing open check-in' do
      existing_check_in = create(:position_check_in, teammate: teammate, employment_tenure: employment_tenure)
      result = PositionCheckIn.find_or_create_open_for(teammate)
      expect(result).to eq(existing_check_in)
    end

    it 'returns nil when no employment tenure exists' do
      employment_tenure.destroy
      result = PositionCheckIn.find_or_create_open_for(teammate)
      expect(result).to be_nil
    end

    it 'creates a new check-in when a finalized one exists' do
      finalized_by = create(:person)
      finalized_check_in = create(:position_check_in, 
        teammate: teammate, 
        employment_tenure: employment_tenure,
        official_check_in_completed_at: 1.day.ago,
        official_rating: 2,
        finalized_by: finalized_by
      )
      
      expect(finalized_check_in.officially_completed?).to be true
      expect(finalized_check_in.open?).to be false
      
      result = PositionCheckIn.find_or_create_open_for(teammate)
      
      expect(result).not_to eq(finalized_check_in)
      expect(result).to be_present
      expect(result.open?).to be true
      expect(result.officially_completed?).to be false
      expect(PositionCheckIn.where(teammate: teammate).open.count).to eq(1)
    end

    it 'excludes finalized check-ins from open scope' do
      finalized_check_in = create(:position_check_in,
        teammate: teammate,
        employment_tenure: employment_tenure,
        official_check_in_completed_at: 1.day.ago
      )
      
      open_check_ins = PositionCheckIn.where(teammate: teammate).open
      expect(open_check_ins).not_to include(finalized_check_in)
      expect(finalized_check_in.open?).to be false
    end
  end

  describe 'latest_finalized_for' do
    it 'returns the most recent finalized check-in' do
      finalized_by = create(:person)
      
      old_finalized = create(:position_check_in,
        teammate: teammate,
        employment_tenure: employment_tenure,
        official_check_in_completed_at: 3.days.ago,
        official_rating: 1,
        finalized_by: finalized_by
      )
      
      recent_finalized = create(:position_check_in,
        teammate: teammate,
        employment_tenure: employment_tenure,
        official_check_in_completed_at: 1.day.ago,
        official_rating: 2,
        finalized_by: finalized_by
      )
      
      result = PositionCheckIn.latest_finalized_for(teammate)
      
      expect(result).to eq(recent_finalized)
      expect(result).not_to eq(old_finalized)
      expect(result.official_rating).to eq(2)
    end

    it 'returns nil when no finalized check-ins exist' do
      open_check_in = create(:position_check_in,
        teammate: teammate,
        employment_tenure: employment_tenure
      )
      
      result = PositionCheckIn.latest_finalized_for(teammate)
      
      expect(result).to be_nil
    end

    it 'returns the latest finalized check-in even when open check-ins exist' do
      finalized_by = create(:person)
      finalized_check_in = create(:position_check_in,
        teammate: teammate,
        employment_tenure: employment_tenure,
        official_check_in_completed_at: 1.day.ago,
        official_rating: 2,
        finalized_by: finalized_by
      )
      
      open_check_in = PositionCheckIn.find_or_create_open_for(teammate)
      
      result = PositionCheckIn.latest_finalized_for(teammate)
      
      expect(result).to eq(finalized_check_in)
      expect(result).not_to eq(open_check_in)
    end
  end

  describe 'employment_tenure association' do
    it 'finds associated employment tenure' do
      expect(check_in.employment_tenure).to eq(employment_tenure)
    end
  end

  describe 'validation: only_one_open_check_in_per_teammate' do
    it 'allows one open check-in per teammate' do
      expect(check_in).to be_valid
    end

    it 'prevents multiple open check-ins per teammate' do
      # First create and save the check-in
      check_in.save!
      
      # Now try to create another one
      duplicate_check_in = build(:position_check_in, teammate: teammate, employment_tenure: employment_tenure)
      expect(duplicate_check_in).not_to be_valid
      expect(duplicate_check_in.errors[:base]).to include('Only one open position check-in allowed per teammate')
    end
  end

  describe 'completion tracking' do
    describe '#complete_employee_side!' do
      it 'marks employee side as completed' do
        expect(check_in.employee_completed?).to be false

        check_in.complete_employee_side!

        expect(check_in.employee_completed?).to be true
        expect(check_in.employee_completed_at).to be_present
      end

      it 'updates ready_for_finalization status when manager already completed' do
        manager = create(:person)
        check_in.complete_manager_side!(completed_by: manager)
        expect(check_in.ready_for_finalization?).to be false

        check_in.complete_employee_side!

        expect(check_in.ready_for_finalization?).to be true
      end
    end

    describe '#complete_manager_side!' do
      it 'marks manager side as completed' do
        manager = create(:person)
        expect(check_in.manager_completed?).to be false

        check_in.complete_manager_side!(completed_by: manager)

        expect(check_in.manager_completed?).to be true
        expect(check_in.manager_completed_at).to be_present
        expect(check_in.manager_completed_by).to eq(manager)
      end

      it 'updates ready_for_finalization status when employee already completed' do
        check_in.complete_employee_side!
        expect(check_in.ready_for_finalization?).to be false

        manager = create(:person)
        check_in.complete_manager_side!(completed_by: manager)

        expect(check_in.ready_for_finalization?).to be true
      end
    end

    describe '#uncomplete_employee_side!' do
      it 'unmarks employee side as completed' do
        check_in.complete_employee_side!
        expect(check_in.employee_completed?).to be true

        check_in.uncomplete_employee_side!

        expect(check_in.employee_completed?).to be false
        expect(check_in.employee_completed_at).to be_nil
      end

      it 'updates ready_for_finalization status when manager completed' do
        manager = create(:person)
        check_in.complete_employee_side!
        check_in.complete_manager_side!(completed_by: manager)
        expect(check_in.ready_for_finalization?).to be true

        check_in.uncomplete_employee_side!

        expect(check_in.ready_for_finalization?).to be false
      end
    end

    describe '#uncomplete_manager_side!' do
      it 'unmarks manager side as completed' do
        manager = create(:person)
        check_in.complete_manager_side!(completed_by: manager)
        expect(check_in.manager_completed?).to be true

        check_in.uncomplete_manager_side!

        expect(check_in.manager_completed?).to be false
        expect(check_in.manager_completed_at).to be_nil
        expect(check_in.manager_completed_by).to be_nil
      end

      it 'updates ready_for_finalization status when employee completed' do
        check_in.complete_employee_side!
        manager = create(:person)
        check_in.complete_manager_side!(completed_by: manager)
        expect(check_in.ready_for_finalization?).to be true

        check_in.uncomplete_manager_side!

        expect(check_in.ready_for_finalization?).to be false
      end
    end

    describe 'completion state transitions' do
      it 'handles multiple complete/uncomplete cycles' do
        manager = create(:person)

        # Complete both sides
        check_in.complete_employee_side!
        check_in.complete_manager_side!(completed_by: manager)
        expect(check_in.ready_for_finalization?).to be true

        # Uncomplete employee side
        check_in.uncomplete_employee_side!
        expect(check_in.ready_for_finalization?).to be false
        expect(check_in.employee_completed?).to be false
        expect(check_in.manager_completed?).to be true

        # Complete employee side again
        check_in.complete_employee_side!
        expect(check_in.ready_for_finalization?).to be true

        # Uncomplete manager side
        check_in.uncomplete_manager_side!
        expect(check_in.ready_for_finalization?).to be false
        expect(check_in.employee_completed?).to be true
        expect(check_in.manager_completed?).to be false

        # Complete manager side again
        check_in.complete_manager_side!(completed_by: manager)
        expect(check_in.ready_for_finalization?).to be true
      end
    end
  end

  describe 'maap_snapshot association' do
    it 'belongs to maap_snapshot' do
      expect(check_in).to respond_to(:maap_snapshot)
      expect(check_in).to respond_to(:maap_snapshot_id)
    end

    it 'can be linked to a snapshot' do
      snapshot = create(:maap_snapshot, employee: person)
      
      check_in.update!(maap_snapshot: snapshot)
      
      expect(check_in.maap_snapshot).to eq(snapshot)
      expect(check_in.maap_snapshot_id).to eq(snapshot.id)
    end

    it 'allows nil maap_snapshot for open check-ins' do
      expect(check_in.maap_snapshot).to be_nil
      expect(check_in.maap_snapshot_id).to be_nil
      expect(check_in).to be_valid
    end

    it 'finalized check-in can be linked to snapshot' do
      finalized_by = create(:person)
      snapshot = create(:maap_snapshot, employee: person)
      
      finalized_check_in = create(:position_check_in,
        teammate: teammate,
        employment_tenure: employment_tenure,
        official_check_in_completed_at: 1.day.ago,
        official_rating: 2,
        finalized_by: finalized_by,
        maap_snapshot: snapshot
      )
      
      expect(finalized_check_in.maap_snapshot).to eq(snapshot)
      expect(finalized_check_in.maap_snapshot_id).to eq(snapshot.id)
    end
  end

  describe 'rating consistency after finalization' do
    let(:manager) { create(:person) }
    let(:manager_teammate) { CompanyTeammate.create!(person: manager, organization: organization) }
    let(:position_type) { create(:position_type, organization: organization) }
    let(:position_level) { create(:position_level, position_major_level: position_type.position_major_level) }
    let(:position) { create(:position, position_type: position_type, position_level: position_level) }
    let(:employment_tenure) do
      EmploymentTenure.find_by(teammate: teammate, company: organization) ||
        create(:employment_tenure,
          teammate: teammate,
          company: organization,
          manager_teammate: manager_teammate,
          position: position,
          started_at: 1.month.ago)
    end
    let(:ready_check_in) do
      create(:position_check_in,
        :ready_for_finalization,
        teammate: teammate,
        employment_tenure: employment_tenure,
        employee_rating: 1,
        manager_rating: 2)
    end

    it 'official_rating matches tenure official_position_rating after finalization' do
      finalizer = Finalizers::PositionCheckInFinalizer.new(
        check_in: ready_check_in,
        official_rating: 2,
        shared_notes: 'Test notes',
        finalized_by: manager
      )
      
      result = finalizer.finalize
      
      expect(result.ok?).to be true
      
      ready_check_in.reload
      closed_tenure = teammate.employment_tenures.inactive.order(ended_at: :desc).first
      
      expect(ready_check_in.official_rating).to eq(2)
      expect(closed_tenure.official_position_rating).to eq(2)
      expect(ready_check_in.official_rating).to eq(closed_tenure.official_position_rating)
    end

    it 'check-in can access snapshot after linking' do
      snapshot = create(:maap_snapshot, employee: person)
      
      finalized_check_in = create(:position_check_in,
        teammate: teammate,
        employment_tenure: employment_tenure,
        official_check_in_completed_at: 1.day.ago,
        official_rating: 2,
        finalized_by: manager,
        maap_snapshot: snapshot
      )
      
      expect(finalized_check_in.maap_snapshot).to eq(snapshot)
      expect(finalized_check_in.maap_snapshot.employee).to eq(person)
    end

    it 'maintains rating consistency when snapshot is linked' do
      snapshot = create(:maap_snapshot, employee: person)
      
      finalized_check_in = create(:position_check_in,
        teammate: teammate,
        employment_tenure: employment_tenure,
        official_check_in_completed_at: 1.day.ago,
        official_rating: 2,
        finalized_by: manager,
        maap_snapshot: snapshot
      )
      
      closed_tenure = teammate.employment_tenures.inactive.order(ended_at: :desc).first
      
      # All should have consistent rating
      expect(finalized_check_in.official_rating).to eq(2)
      if closed_tenure
        expect(closed_tenure.official_position_rating).to eq(2)
        expect(finalized_check_in.official_rating).to eq(closed_tenure.official_position_rating)
      end
      
      # Snapshot should be accessible
      expect(finalized_check_in.maap_snapshot).to eq(snapshot)
    end
  end
end