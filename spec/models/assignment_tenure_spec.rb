require 'rails_helper'

RSpec.describe AssignmentTenure, type: :model do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, person: person, organization: organization) }
  let(:assignment) { create(:assignment, company: organization) }

  describe 'validations' do
    it 'requires started_at' do
      tenure = AssignmentTenure.new(teammate: teammate, assignment: assignment)
      expect(tenure).not_to be_valid
      expect(tenure.errors[:started_at]).to include("can't be blank")
    end

    it 'validates ended_at is after started_at' do
      tenure = AssignmentTenure.new(
        teammate: teammate,
        assignment: assignment,
        started_at: Date.current,
        ended_at: Date.current - 1.day
      )
      expect(tenure).not_to be_valid
      expect(tenure.errors[:ended_at]).to be_present
    end

    it 'prevents overlapping active tenures for same teammate and assignment' do
      create(:assignment_tenure, 
             teammate: teammate, 
             assignment: assignment, 
             started_at: Date.current - 1.month,
             ended_at: nil)
      
      overlapping_tenure = AssignmentTenure.new(
        teammate: teammate,
        assignment: assignment,
        started_at: Date.current,
        ended_at: nil
      )
      
      expect(overlapping_tenure).not_to be_valid
      expect(overlapping_tenure.errors[:base]).to include('Cannot have overlapping active assignment tenures for the same teammate and assignment')
    end

    it 'allows multiple tenures if previous ones are ended' do
      create(:assignment_tenure,
             teammate: teammate,
             assignment: assignment,
             started_at: Date.current - 2.months,
             ended_at: Date.current - 1.month)
      
      new_tenure = AssignmentTenure.new(
        teammate: teammate,
        assignment: assignment,
        started_at: Date.current,
        ended_at: nil
      )
      
      expect(new_tenure).to be_valid
    end
  end

  describe 'scopes' do
    let!(:active_tenure) { create(:assignment_tenure, teammate: teammate, assignment: assignment, started_at: Date.current - 1.month, ended_at: nil) }
    let!(:inactive_tenure) { create(:assignment_tenure, teammate: teammate, assignment: create(:assignment, company: organization), started_at: Date.current - 2.months, ended_at: Date.current - 1.month) }

    it 'returns active tenures' do
      expect(AssignmentTenure.active).to include(active_tenure)
      expect(AssignmentTenure.active).not_to include(inactive_tenure)
    end

    it 'returns inactive tenures' do
      expect(AssignmentTenure.inactive).to include(inactive_tenure)
      expect(AssignmentTenure.inactive).not_to include(active_tenure)
    end
  end

  describe '#active?' do
    it 'returns true when ended_at is nil' do
      tenure = build(:assignment_tenure, ended_at: nil)
      expect(tenure.active?).to be true
    end

    it 'returns false when ended_at is set' do
      tenure = build(:assignment_tenure, ended_at: Date.current)
      expect(tenure.active?).to be false
    end
  end

  describe 'creating tenure with default energy percentage' do
    it 'can create tenure with 0% energy' do
      tenure = AssignmentTenure.create!(
        teammate: teammate,
        assignment: assignment,
        started_at: Date.current,
        anticipated_energy_percentage: 0
      )
      
      expect(tenure.anticipated_energy_percentage).to eq(0)
      expect(tenure).to be_persisted
    end

    it 'allows nil energy percentage' do
      tenure = AssignmentTenure.create!(
        teammate: teammate,
        assignment: assignment,
        started_at: Date.current,
        anticipated_energy_percentage: nil
      )
      
      expect(tenure.anticipated_energy_percentage).to be_nil
      expect(tenure).to be_persisted
    end
  end
end
