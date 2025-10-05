require 'rails_helper'

RSpec.describe AssignmentCheckIn, type: :model do
  let(:person) { create(:person) }
  let(:organization) { create(:organization) }
  let(:teammate) { create(:teammate, person: person, organization: organization) }
  let(:assignment) { create(:assignment, company: organization) }
  let(:check_in) { create(:assignment_check_in, teammate: teammate, assignment: assignment) }

  describe 'validations' do
    it 'validates check_in_started_on presence' do
      check_in = build(:assignment_check_in, check_in_started_on: nil)
      expect(check_in).not_to be_valid
      expect(check_in.errors[:check_in_started_on]).to include("can't be blank")
    end

    it 'validates actual_energy_percentage range' do
      check_in = build(:assignment_check_in, actual_energy_percentage: 150)
      expect(check_in).not_to be_valid
      expect(check_in.errors[:actual_energy_percentage]).to include('is not included in the list')
    end

    it 'allows nil actual_energy_percentage' do
      check_in = build(:assignment_check_in, actual_energy_percentage: nil)
      expect(check_in).to be_valid
    end

    it 'validates employee_rating inclusion' do
      expect {
        build(:assignment_check_in, employee_rating: 'invalid')
      }.to raise_error(ArgumentError, "'invalid' is not a valid employee_rating")
    end

    it 'validates manager_rating inclusion' do
      expect {
        build(:assignment_check_in, manager_rating: 'invalid')
      }.to raise_error(ArgumentError, "'invalid' is not a valid manager_rating")
    end

    it 'validates employee_personal_alignment inclusion' do
      expect {
        build(:assignment_check_in, employee_personal_alignment: 'invalid')
      }.to raise_error(ArgumentError, "'invalid' is not a valid employee_personal_alignment")
    end

    it 'prevents multiple open check-ins per teammate per assignment' do
      create(:assignment_check_in, teammate: teammate, assignment: assignment)
      duplicate_check_in = build(:assignment_check_in, teammate: teammate, assignment: assignment)
      
      expect(duplicate_check_in).not_to be_valid
      expect(duplicate_check_in.errors[:base]).to include('Only one open check-in allowed per teammate per assignment')
    end

    it 'allows multiple check-ins for different assignments' do
      other_assignment = create(:assignment, company: organization)
      create(:assignment_check_in, teammate: teammate, assignment: assignment)
      other_check_in = build(:assignment_check_in, teammate: teammate, assignment: other_assignment)
      
      expect(other_check_in).to be_valid
    end

    it 'allows multiple check-ins for different teammates' do
      other_person = create(:person)
      other_teammate = create(:teammate, person: other_person, organization: organization)
      create(:assignment_check_in, teammate: teammate, assignment: assignment)
      other_check_in = build(:assignment_check_in, teammate: other_teammate, assignment: assignment)
      
      expect(other_check_in).to be_valid
    end
  end

  describe 'completion tracking' do
    describe '#employee_completed?' do
      it 'returns false when employee_completed_at is nil' do
        expect(check_in.employee_completed?).to be false
      end

      it 'returns true when employee_completed_at is present' do
        check_in.update!(employee_completed_at: Time.current)
        expect(check_in.employee_completed?).to be true
      end
    end

    describe '#manager_completed?' do
      it 'returns false when manager_completed_at is nil' do
        expect(check_in.manager_completed?).to be false
      end

      it 'returns true when manager_completed_at is present' do
        check_in.update!(manager_completed_at: Time.current)
        expect(check_in.manager_completed?).to be true
      end
    end

    describe '#officially_completed?' do
      it 'returns false when official_check_in_completed_at is nil' do
        expect(check_in.officially_completed?).to be false
      end

      it 'returns true when official_check_in_completed_at is present' do
        check_in.update!(official_check_in_completed_at: Time.current)
        expect(check_in.officially_completed?).to be true
      end
    end

    describe '#ready_for_finalization?' do
      it 'returns false when neither employee nor manager completed' do
        expect(check_in.ready_for_finalization?).to be false
      end

      it 'returns false when only employee completed' do
        check_in.complete_employee_side!
        expect(check_in.ready_for_finalization?).to be false
      end

      it 'returns false when only manager completed' do
        check_in.complete_manager_side!
        expect(check_in.ready_for_finalization?).to be false
      end

      it 'returns true when both employee and manager completed' do
        check_in.complete_employee_side!
        check_in.complete_manager_side!
        expect(check_in.ready_for_finalization?).to be true
      end

      it 'returns false when already officially completed' do
        check_in.complete_employee_side!
        check_in.complete_manager_side!
        check_in.finalize_check_in!(final_rating: 'meeting')
        expect(check_in.ready_for_finalization?).to be false
      end
    end
  end

  describe 'completion methods' do
    describe '#complete_employee_side!' do
      it 'sets employee_completed_at to current time' do
        expect(check_in.employee_completed_at).to be_nil
        check_in.complete_employee_side!
        expect(check_in.employee_completed_at).to be_present
        expect(check_in.employee_completed_at).to be_within(1.second).of(Time.current)
      end
    end

    describe '#complete_manager_side!' do
      it 'sets manager_completed_at to current time' do
        expect(check_in.manager_completed_at).to be_nil
        check_in.complete_manager_side!
        expect(check_in.manager_completed_at).to be_present
        expect(check_in.manager_completed_at).to be_within(1.second).of(Time.current)
      end
    end

    describe '#uncomplete_employee_side!' do
      it 'sets employee_completed_at to nil' do
        check_in.update!(employee_completed_at: Time.current)
        check_in.uncomplete_employee_side!
        expect(check_in.employee_completed_at).to be_nil
      end
    end

    describe '#uncomplete_manager_side!' do
      it 'sets manager_completed_at to nil' do
        check_in.update!(manager_completed_at: Time.current)
        check_in.uncomplete_manager_side!
        expect(check_in.manager_completed_at).to be_nil
      end
    end

    describe '#finalize_check_in!' do
      it 'sets official_check_in_completed_at and official_rating' do
        expect(check_in.official_check_in_completed_at).to be_nil
        check_in.finalize_check_in!(final_rating: 'exceeding')
        expect(check_in.official_check_in_completed_at).to be_present
        expect(check_in.official_check_in_completed_at).to be_within(1.second).of(Time.current)
        expect(check_in.official_rating).to eq('exceeding')
      end

      it 'raises error when final_rating is blank' do
        expect {
          check_in.finalize_check_in!(final_rating: nil)
        }.to raise_error(ArgumentError, 'Final rating is required for check-in finalization')
      end

      it 'raises error when final_rating is empty string' do
        expect {
          check_in.finalize_check_in!(final_rating: '')
        }.to raise_error(ArgumentError, 'Final rating is required for check-in finalization')
      end
    end
  end

  describe 'scopes' do
    let!(:employee_completed) { create(:assignment_check_in, :employee_completed) }
    let!(:manager_completed) { create(:assignment_check_in, :manager_completed) }
    let!(:both_completed) { create(:assignment_check_in, :ready_for_finalization) }
    let!(:officially_completed) { create(:assignment_check_in, :officially_completed) }

    describe '.employee_completed' do
      it 'returns only check-ins with employee_completed_at' do
        result = AssignmentCheckIn.employee_completed
        expect(result).to include(employee_completed, both_completed, officially_completed)
        expect(result).not_to include(manager_completed, check_in)
      end
    end

    describe '.manager_completed' do
      it 'returns only check-ins with manager_completed_at' do
        result = AssignmentCheckIn.manager_completed
        expect(result).to include(manager_completed, both_completed, officially_completed)
        expect(result).not_to include(employee_completed, check_in)
      end
    end

    describe '.officially_completed' do
      it 'returns only check-ins with official_check_in_completed_at' do
        result = AssignmentCheckIn.officially_completed
        expect(result).to include(officially_completed)
        expect(result).not_to include(employee_completed, manager_completed, both_completed, check_in)
      end
    end

    describe '.ready_for_finalization' do
      it 'returns only check-ins ready for finalization' do
        result = AssignmentCheckIn.ready_for_finalization
        expect(result).to include(both_completed)
        expect(result).not_to include(employee_completed, manager_completed, officially_completed, check_in)
      end
    end

    describe '.open' do
      it 'returns only non-officially-completed check-ins' do
        result = AssignmentCheckIn.open
        expect(result).to include(employee_completed, manager_completed, both_completed, check_in)
        expect(result).not_to include(officially_completed)
      end
    end

    describe '.closed' do
      it 'returns only officially-completed check-ins' do
        result = AssignmentCheckIn.closed
        expect(result).to include(officially_completed)
        expect(result).not_to include(employee_completed, manager_completed, both_completed, check_in)
      end
    end
  end

  describe 'state transitions' do
    it 'follows the correct state progression' do
      # Initial state
      expect(check_in.employee_completed?).to be false
      expect(check_in.manager_completed?).to be false
      expect(check_in.officially_completed?).to be false
      expect(check_in.ready_for_finalization?).to be false

      # Employee completes
      check_in.complete_employee_side!
      expect(check_in.employee_completed?).to be true
      expect(check_in.manager_completed?).to be false
      expect(check_in.officially_completed?).to be false
      expect(check_in.ready_for_finalization?).to be false

      # Manager completes
      check_in.complete_manager_side!
      expect(check_in.employee_completed?).to be true
      expect(check_in.manager_completed?).to be true
      expect(check_in.officially_completed?).to be false
      expect(check_in.ready_for_finalization?).to be true

      # Finalize
      check_in.finalize_check_in!(final_rating: 'meeting')
      expect(check_in.employee_completed?).to be true
      expect(check_in.manager_completed?).to be true
      expect(check_in.officially_completed?).to be true
      expect(check_in.ready_for_finalization?).to be false
    end

    it 'allows uncompleting and recompleting' do
      # Complete both sides
      check_in.complete_employee_side!
      check_in.complete_manager_side!
      expect(check_in.ready_for_finalization?).to be true

      # Uncomplete employee side
      check_in.uncomplete_employee_side!
      expect(check_in.employee_completed?).to be false
      expect(check_in.manager_completed?).to be true
      expect(check_in.ready_for_finalization?).to be false

      # Recomplete employee side
      check_in.complete_employee_side!
      expect(check_in.employee_completed?).to be true
      expect(check_in.manager_completed?).to be true
      expect(check_in.ready_for_finalization?).to be true
    end
  end
end