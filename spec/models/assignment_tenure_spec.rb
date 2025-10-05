require 'rails_helper'

RSpec.describe AssignmentTenure, type: :model do
  let(:person) { create(:person) }
  let(:assignment) { create(:assignment) }
  let(:teammate) { create(:teammate, person: person, organization: assignment.company) }

  describe 'validations' do
    it 'requires started_at' do
      tenure = build(:assignment_tenure, started_at: nil)
      expect(tenure).not_to be_valid
      expect(tenure.errors[:started_at]).to include("can't be blank")
    end

    it 'validates ended_at is after started_at' do
      tenure = build(:assignment_tenure, started_at: Date.current, ended_at: 1.day.ago)
      expect(tenure).not_to be_valid
      expect(tenure.errors[:ended_at]).to include("must be greater than or equal to #{tenure.started_at}")
    end

    it 'allows nil ended_at for active tenures' do
      tenure = build(:assignment_tenure, started_at: Date.current, ended_at: nil)
      expect(tenure).to be_valid
    end

    it 'validates anticipated_energy_percentage is between 0-100' do
      tenure = build(:assignment_tenure, anticipated_energy_percentage: 150)
      expect(tenure).not_to be_valid
      expect(tenure.errors[:anticipated_energy_percentage]).to include('is not included in the list')
    end

    it 'allows nil anticipated_energy_percentage' do
      tenure = build(:assignment_tenure, anticipated_energy_percentage: nil)
      expect(tenure).to be_valid
    end
  end

  describe 'overlapping tenures validation' do
    let!(:existing_tenure) do
      create(:assignment_tenure, 
        teammate: teammate, 
        assignment: assignment, 
        started_at: 1.month.ago, 
        ended_at: nil)
    end

    it 'prevents overlapping active tenures for same person and assignment' do
      overlapping_tenure = build(:assignment_tenure, 
        teammate: teammate, 
        assignment: assignment, 
        started_at: 2.weeks.ago, 
        ended_at: nil)
      
      expect(overlapping_tenure).not_to be_valid
      expect(overlapping_tenure.errors[:base]).to include('Cannot have overlapping active assignment tenures for the same teammate and assignment')
    end

    it 'allows overlapping tenures for different people' do
      other_person = create(:person)
      other_teammate = create(:teammate, person: other_person, organization: assignment.company)
      overlapping_tenure = build(:assignment_tenure, 
        teammate: other_teammate, 
        assignment: assignment, 
        started_at: 2.weeks.ago, 
        ended_at: nil)
      
      expect(overlapping_tenure).to be_valid
    end

    it 'allows overlapping tenures for different assignments' do
      other_assignment = create(:assignment)
      overlapping_tenure = build(:assignment_tenure, 
        teammate: teammate, 
        assignment: other_assignment, 
        started_at: 2.weeks.ago, 
        ended_at: nil)
      
      expect(overlapping_tenure).to be_valid
    end

    it 'allows new tenure after existing tenure ends' do
      existing_tenure.update!(ended_at: 1.week.ago)
      
      new_tenure = build(:assignment_tenure, 
        teammate: teammate, 
        assignment: assignment, 
        started_at: 3.days.ago, 
        ended_at: nil)
      
      expect(new_tenure).to be_valid
    end
  end

  describe 'scopes' do
    let!(:active_tenure) { create(:assignment_tenure, ended_at: nil) }
    let!(:inactive_tenure) { create(:assignment_tenure, started_at: 2.days.ago, ended_at: 1.day.ago) }

    describe '.active' do
      it 'returns only active assignment tenures' do
        expect(AssignmentTenure.active).to include(active_tenure)
        expect(AssignmentTenure.active).not_to include(inactive_tenure)
      end
    end

    describe '.inactive' do
      it 'returns only inactive assignment tenures' do
        expect(AssignmentTenure.inactive).to include(inactive_tenure)
        expect(AssignmentTenure.inactive).not_to include(active_tenure)
      end
    end

    describe '.most_recent_for_teammate_and_assignment' do
      let(:person) { create(:person) }
      let(:assignment) { create(:assignment) }
      let(:teammate) { create(:teammate, person: person, organization: assignment.company) }
      let!(:old_tenure) { create(:assignment_tenure, teammate: teammate, assignment: assignment, started_at: 2.years.ago, ended_at: 1.year.ago) }
      let!(:new_tenure) { create(:assignment_tenure, teammate: teammate, assignment: assignment, started_at: 1.year.ago) }

      it 'returns the most recent assignment tenure for a teammate and assignment' do
        result = AssignmentTenure.most_recent_for_teammate_and_assignment(teammate, assignment)
        expect(result.first).to eq(new_tenure)
      end
    end
  end

  describe '.most_recent_for' do
    let(:person) { create(:person) }
    let(:assignment) { create(:assignment) }
    let(:teammate) { create(:teammate, person: person, organization: assignment.company) }
    let!(:old_tenure) { create(:assignment_tenure, teammate: teammate, assignment: assignment, started_at: 2.years.ago, ended_at: 1.year.ago) }
    let!(:new_tenure) { create(:assignment_tenure, teammate: teammate, assignment: assignment, started_at: 1.year.ago) }

    it 'returns the most recent assignment tenure for a teammate and assignment' do
      result = AssignmentTenure.most_recent_for(teammate, assignment)
      expect(result).to eq(new_tenure)
    end

    it 'returns nil when no assignment tenures exist' do
      other_person = create(:person)
      other_teammate = create(:teammate, person: other_person, organization: assignment.company)
      result = AssignmentTenure.most_recent_for(other_teammate, assignment)
      expect(result).to be_nil
    end
  end

  describe '#active?' do
    it 'returns true when ended_at is nil' do
      tenure = build(:assignment_tenure, ended_at: nil)
      expect(tenure.active?).to be true
    end

    it 'returns false when ended_at is set' do
      tenure = build(:assignment_tenure, ended_at: 1.day.ago)
      expect(tenure.active?).to be false
    end
  end

  describe '#inactive?' do
    it 'returns false when ended_at is nil' do
      tenure = build(:assignment_tenure, ended_at: nil)
      expect(tenure.inactive?).to be false
    end

    it 'returns true when ended_at is set' do
      tenure = build(:assignment_tenure, ended_at: 1.day.ago)
      expect(tenure.inactive?).to be true
    end
  end
end
