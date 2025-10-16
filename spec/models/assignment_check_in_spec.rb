require 'rails_helper'

RSpec.describe AssignmentCheckIn, type: :model do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, person: person, organization: organization) }
    let(:assignment) { create(:assignment, company: organization) }
  let(:assignment_tenure) do
    create(:assignment_tenure,
           teammate: teammate,
           assignment: assignment,
           anticipated_energy_percentage: 80,
           started_at: 1.month.ago)
  end

  describe 'CheckInBehavior integration' do
    it 'includes CheckInBehavior concern' do
      expect(AssignmentCheckIn.ancestors).to include(CheckInBehavior)
    end

    it 'has required associations from CheckInBehavior' do
      check_in = AssignmentCheckIn.new(teammate: teammate, assignment: assignment)
      expect(check_in).to respond_to(:teammate)
      expect(check_in).to respond_to(:finalized_by)
      expect(check_in).to respond_to(:maap_snapshot)
    end

    it 'has common scopes from CheckInBehavior' do
      expect(AssignmentCheckIn).to respond_to(:recent)
      expect(AssignmentCheckIn).to respond_to(:for_teammate)
      expect(AssignmentCheckIn).to respond_to(:open)
      expect(AssignmentCheckIn).to respond_to(:closed)
      expect(AssignmentCheckIn).to respond_to(:employee_completed)
      expect(AssignmentCheckIn).to respond_to(:manager_completed)
      expect(AssignmentCheckIn).to respond_to(:ready_for_finalization)
    end

    it 'has status methods from CheckInBehavior' do
      check_in = AssignmentCheckIn.new(teammate: teammate, assignment: assignment)
      expect(check_in).to respond_to(:open?)
      expect(check_in).to respond_to(:closed?)
      expect(check_in).to respond_to(:employee_completed?)
      expect(check_in).to respond_to(:manager_completed?)
      expect(check_in).to respond_to(:officially_completed?)
      expect(check_in).to respond_to(:ready_for_finalization?)
    end

    it 'has completion actions from CheckInBehavior' do
      check_in = AssignmentCheckIn.new(teammate: teammate, assignment: assignment)
      expect(check_in).to respond_to(:complete_employee_side!)
      expect(check_in).to respond_to(:complete_manager_side!)
      expect(check_in).to respond_to(:uncomplete_employee_side!)
      expect(check_in).to respond_to(:uncomplete_manager_side!)
    end
  end

  describe 'Assignment-specific functionality' do
    it 'belongs to assignment' do
      check_in = AssignmentCheckIn.new(teammate: teammate, assignment: assignment)
      expect(check_in.assignment).to eq(assignment)
    end

    it 'has assignment-specific enums' do
      expect(AssignmentCheckIn.employee_ratings.keys).to match_array(['working_to_meet', 'meeting', 'exceeding'])
      expect(AssignmentCheckIn.manager_ratings.keys).to match_array(['working_to_meet', 'meeting', 'exceeding'])
      expect(AssignmentCheckIn.official_ratings.keys).to match_array(['working_to_meet', 'meeting', 'exceeding'])
    end

    it 'has personal alignment enum' do
      expect(AssignmentCheckIn.employee_personal_alignments.keys).to match_array(['love', 'like', 'neutral', 'prefer_not', 'only_if_necessary'])
    end

    it 'validates actual_energy_percentage range' do
      check_in = AssignmentCheckIn.new(
        teammate: teammate,
        assignment: assignment,
        actual_energy_percentage: 150
      )
      expect(check_in).not_to be_valid
      expect(check_in.errors[:actual_energy_percentage]).to include('is not included in the list')
    end

    it 'allows nil actual_energy_percentage' do
      check_in = AssignmentCheckIn.new(
        teammate: teammate,
        assignment: assignment,
        actual_energy_percentage: nil,
        check_in_started_on: Date.current
      )
      expect(check_in).to be_valid
    end
  end

  describe 'find_or_create_open_for' do
    before { assignment_tenure }

    it 'creates new check-in when none exists' do
      expect {
        AssignmentCheckIn.find_or_create_open_for(teammate, assignment)
      }.to change(AssignmentCheckIn, :count).by(1)
    end

    it 'returns existing open check-in' do
      existing_check_in = AssignmentCheckIn.create!(
        teammate: teammate,
        assignment: assignment,
        check_in_started_on: Date.current,
        actual_energy_percentage: 80
      )

      result = AssignmentCheckIn.find_or_create_open_for(teammate, assignment)
      expect(result).to eq(existing_check_in)
    end

    it 'sets actual_energy_percentage from anticipated' do
      check_in = AssignmentCheckIn.find_or_create_open_for(teammate, assignment)
      expect(check_in.actual_energy_percentage).to eq(80)
    end

    it 'returns nil when no assignment tenure exists' do
      assignment_tenure.destroy
      result = AssignmentCheckIn.find_or_create_open_for(teammate, assignment)
      expect(result).to be_nil
    end
  end

  describe 'assignment_tenure association' do
    before { assignment_tenure }

    it 'finds associated assignment tenure' do
      check_in = AssignmentCheckIn.create!(
        teammate: teammate,
        assignment: assignment,
        check_in_started_on: Date.current
      )

      expect(check_in.assignment_tenure).to eq(assignment_tenure)
    end
  end

  describe 'validation: only_one_open_check_in_per_teammate_assignment' do
    before { assignment_tenure }

    it 'allows one open check-in per teammate per assignment' do
      check_in = AssignmentCheckIn.create!(
        teammate: teammate,
        assignment: assignment,
        check_in_started_on: Date.current
      )
      expect(check_in).to be_valid
    end

    it 'prevents multiple open check-ins per teammate per assignment' do
      AssignmentCheckIn.create!(
        teammate: teammate,
        assignment: assignment,
        check_in_started_on: Date.current
      )

      duplicate_check_in = AssignmentCheckIn.new(
        teammate: teammate,
        assignment: assignment,
        check_in_started_on: Date.current
      )
      
      expect(duplicate_check_in).not_to be_valid
      expect(duplicate_check_in.errors[:base]).to include('Only one open check-in allowed per teammate per assignment')
    end

    it 'allows multiple check-ins for different assignments' do
        assignment2 = create(:assignment, company: organization)
      create(:assignment_tenure,
             teammate: teammate,
             assignment: assignment2,
             anticipated_energy_percentage: 60,
             started_at: 1.month.ago)

      AssignmentCheckIn.create!(
        teammate: teammate,
        assignment: assignment,
        check_in_started_on: Date.current
      )

      check_in2 = AssignmentCheckIn.create!(
        teammate: teammate,
        assignment: assignment2,
        check_in_started_on: Date.current
      )

      expect(check_in2).to be_valid
    end

    it 'allows multiple check-ins for different teammates' do
      teammate2 = create(:teammate, organization: organization)
      create(:assignment_tenure,
             teammate: teammate2,
             assignment: assignment,
             anticipated_energy_percentage: 70,
             started_at: 1.month.ago)

      AssignmentCheckIn.create!(
        teammate: teammate,
        assignment: assignment,
        check_in_started_on: Date.current
      )

      check_in2 = AssignmentCheckIn.create!(
        teammate: teammate2,
        assignment: assignment,
        check_in_started_on: Date.current
      )

      expect(check_in2).to be_valid
    end
  end

  describe 'completion tracking' do
    let(:check_in) do
      AssignmentCheckIn.create!(
        teammate: teammate,
        assignment: assignment,
        check_in_started_on: Date.current
      )
    end

    it 'tracks employee completion' do
      expect(check_in.employee_completed?).to be false
      
      check_in.complete_employee_side!
        expect(check_in.employee_completed?).to be true
      expect(check_in.employee_completed_at).to be_present
    end

    it 'tracks manager completion' do
      manager = create(:person)
        expect(check_in.manager_completed?).to be false

      check_in.complete_manager_side!(completed_by: manager)
        expect(check_in.manager_completed?).to be true
      expect(check_in.manager_completed_at).to be_present
      expect(check_in.manager_completed_by).to eq(manager)
    end

    it 'tracks official completion' do
        expect(check_in.officially_completed?).to be false

        check_in.update!(official_check_in_completed_at: Time.current)
        expect(check_in.officially_completed?).to be true
    end

    it 'determines ready for finalization correctly' do
        expect(check_in.ready_for_finalization?).to be false

        check_in.complete_employee_side!
        expect(check_in.ready_for_finalization?).to be false
      
      check_in.complete_manager_side!(completed_by: create(:person))
        expect(check_in.ready_for_finalization?).to be true

      check_in.update!(official_check_in_completed_at: Time.current)
        expect(check_in.ready_for_finalization?).to be false
    end
  end

  describe 'finalize_check_in!' do
    let(:check_in) do
      AssignmentCheckIn.create!(
        teammate: teammate,
        assignment: assignment,
        check_in_started_on: Date.current
      )
    end

    it 'finalizes check-in with rating and finalized_by' do
      manager = create(:person)
      
      check_in.finalize_check_in!(final_rating: 'exceeding', finalized_by: manager)
      
      expect(check_in.officially_completed?).to be true
      expect(check_in.official_rating).to eq('exceeding')
      expect(check_in.finalized_by).to eq(manager)
      expect(check_in.official_check_in_completed_at).to be_present
    end

    it 'raises error without final rating' do
        expect {
          check_in.finalize_check_in!(final_rating: nil)
        }.to raise_error(ArgumentError, 'Final rating is required for check-in finalization')
    end
  end

  describe 'started tracking' do
    let(:check_in) do
      AssignmentCheckIn.create!(
        teammate: teammate,
        assignment: assignment,
        check_in_started_on: Date.current
      )
    end

    it 'tracks employee started state' do
      expect(check_in.employee_started?).to be false
      
      check_in.update!(actual_energy_percentage: 75)
      expect(check_in.employee_started?).to be true
      
      check_in.update!(actual_energy_percentage: nil, employee_personal_alignment: 'like')
      expect(check_in.employee_started?).to be true
      
      check_in.update!(employee_personal_alignment: nil, employee_rating: 'meeting')
      expect(check_in.employee_started?).to be true
      
      check_in.update!(employee_rating: nil, employee_private_notes: 'Some notes')
      expect(check_in.employee_started?).to be true
    end

    it 'tracks manager started state' do
      expect(check_in.manager_started?).to be false
      
      check_in.update!(manager_rating: 'exceeding')
      expect(check_in.manager_started?).to be true
      
      check_in.update!(manager_rating: nil, manager_private_notes: 'Some notes')
      expect(check_in.manager_started?).to be true
    end
  end
end