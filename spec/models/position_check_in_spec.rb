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
end