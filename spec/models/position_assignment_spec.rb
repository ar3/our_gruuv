require 'rails_helper'

RSpec.describe PositionAssignment, type: :model do
  let(:company) { create(:organization, type: 'Company') }
  let(:position_major_level) { create(:position_major_level) }
  let(:position_level) { create(:position_level, position_major_level: position_major_level) }
  let(:title) { create(:title, organization: company, position_major_level: position_major_level) }
  let(:position) { create(:position, title: title, position_level: position_level) }
  let(:assignment) { create(:assignment, company: company) }
  let(:position_assignment) { create(:position_assignment, position: position, assignment: assignment) }

  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(position_assignment).to be_valid
    end

    it 'requires position' do
      position_assignment.position = nil
      expect(position_assignment).not_to be_valid
    end

    it 'requires assignment' do
      position_assignment.assignment = nil
      expect(position_assignment).not_to be_valid
    end

    it 'requires assignment_type' do
      position_assignment.assignment_type = nil
      expect(position_assignment).not_to be_valid
    end

    it 'accepts required assignment_type' do
      position_assignment.assignment_type = 'required'
      expect(position_assignment).to be_valid
    end

    it 'accepts suggested assignment_type' do
      position_assignment.assignment_type = 'suggested'
      expect(position_assignment).to be_valid
    end

    it 'rejects invalid assignment_type' do
      position_assignment.assignment_type = 'invalid'
      expect(position_assignment).not_to be_valid
    end

    describe 'energy metadata' do
      it 'accepts valid min_estimated_energy' do
        position_assignment.min_estimated_energy = 25
        expect(position_assignment).to be_valid
      end

      it 'accepts min_estimated_energy of 0' do
        position_assignment.min_estimated_energy = 0
        expect(position_assignment).to be_valid
      end

      it 'accepts valid max_estimated_energy' do
        position_assignment.max_estimated_energy = 75
        expect(position_assignment).to be_valid
      end

      it 'rejects min_estimated_energy greater than 100' do
        position_assignment.min_estimated_energy = 101
        expect(position_assignment).not_to be_valid
        expect(position_assignment.errors[:min_estimated_energy]).to include('must be less than or equal to 100')
      end

      it 'rejects max_estimated_energy greater than 100' do
        position_assignment.max_estimated_energy = 101
        expect(position_assignment).not_to be_valid
        expect(position_assignment.errors[:max_estimated_energy]).to include('must be less than or equal to 100')
      end

      it 'rejects negative min_estimated_energy' do
        position_assignment.min_estimated_energy = -1
        expect(position_assignment).not_to be_valid
        expect(position_assignment.errors[:min_estimated_energy]).to include('must be greater than or equal to 0')
      end

      it 'rejects negative max_estimated_energy' do
        position_assignment.max_estimated_energy = -1
        expect(position_assignment).not_to be_valid
        expect(position_assignment.errors[:max_estimated_energy]).to include('must be greater than 0')
      end

      it 'accepts equal min and max energy values' do
        position_assignment.min_estimated_energy = 50
        position_assignment.max_estimated_energy = 50
        expect(position_assignment).to be_valid
      end

      it 'rejects max_estimated_energy less than min_estimated_energy' do
        position_assignment.min_estimated_energy = 75
        position_assignment.max_estimated_energy = 50
        expect(position_assignment).not_to be_valid
        expect(position_assignment.errors[:max_estimated_energy]).to include('must be greater than minimum energy')
      end

      it 'accepts valid energy range' do
        position_assignment.min_estimated_energy = 25
        position_assignment.max_estimated_energy = 75
        expect(position_assignment).to be_valid
      end

      it 'allows nil values' do
        position_assignment.min_estimated_energy = nil
        position_assignment.max_estimated_energy = nil
        expect(position_assignment).to be_valid
      end
    end

    describe 'uniqueness' do
      it 'prevents duplicate position and assignment combination' do
        create(:position_assignment, position: position, assignment: assignment)
        
        duplicate = build(:position_assignment, position: position, assignment: assignment)
        expect(duplicate).not_to be_valid
      end

      it 'allows same assignment with different position' do
        other_position = create(:position, title: title, position_level: create(:position_level, position_major_level: position_major_level))
        create(:position_assignment, position: position, assignment: assignment)
        
        new_assignment = build(:position_assignment, position: other_position, assignment: assignment)
        expect(new_assignment).to be_valid
      end

      it 'allows same position with different assignment' do
        other_assignment = create(:assignment, company: company)
        create(:position_assignment, position: position, assignment: assignment)
        
        new_assignment = build(:position_assignment, position: position, assignment: other_assignment)
        expect(new_assignment).to be_valid
      end
    end
  end

  describe 'associations' do
    it 'belongs to a position' do
      expect(position_assignment.position).to eq(position)
    end

    it 'belongs to an assignment' do
      expect(position_assignment.assignment).to eq(assignment)
    end
  end

  describe 'scopes' do
    let!(:required_assignment) { create(:position_assignment, :required, position: position, assignment: assignment) }
    let!(:suggested_assignment) { create(:position_assignment, :suggested, position: position, assignment: create(:assignment, company: company)) }

    it 'filters by required type' do
      expect(PositionAssignment.required).to include(required_assignment)
      expect(PositionAssignment.required).not_to include(suggested_assignment)
    end

    it 'filters by suggested type' do
      expect(PositionAssignment.suggested).to include(suggested_assignment)
      expect(PositionAssignment.suggested).not_to include(required_assignment)
    end
  end

  describe 'instance methods' do
    it 'returns display name' do
      expect(position_assignment.display_name).to eq("#{assignment.title} (required)")
    end

    it 'returns display name for suggested type' do
      suggested = create(:position_assignment, :suggested, position: position, assignment: assignment)
      expect(suggested.display_name).to eq("#{assignment.title} (suggested)")
    end

    describe 'energy_range_display' do
      it 'displays range when both min and max are present' do
        position_assignment.min_estimated_energy = 25
        position_assignment.max_estimated_energy = 75
        expect(position_assignment.energy_range_display).to eq('25%-75% of effort')
      end

      it 'displays min only when only min is present' do
        position_assignment.min_estimated_energy = 30
        position_assignment.max_estimated_energy = nil
        expect(position_assignment.energy_range_display).to eq('30%+ of effort')
      end

      it 'displays max only when only max is present' do
        position_assignment.min_estimated_energy = nil
        position_assignment.max_estimated_energy = 60
        expect(position_assignment.energy_range_display).to eq('Up to 60% of effort')
      end

      it 'displays no estimate when neither is present' do
        position_assignment.min_estimated_energy = nil
        position_assignment.max_estimated_energy = nil
        expect(position_assignment.energy_range_display).to eq('No effort estimate')
      end
    end

    describe 'anticipated_energy_percentage' do
      it 'returns average when both min and max are present' do
        position_assignment.min_estimated_energy = 20
        position_assignment.max_estimated_energy = 40
        expect(position_assignment.anticipated_energy_percentage).to eq(30)
      end

      it 'rounds the average correctly' do
        position_assignment.min_estimated_energy = 25
        position_assignment.max_estimated_energy = 50
        expect(position_assignment.anticipated_energy_percentage).to eq(38)
      end

      it 'returns min when only min is present' do
        position_assignment.min_estimated_energy = 30
        position_assignment.max_estimated_energy = nil
        expect(position_assignment.anticipated_energy_percentage).to eq(30)
      end

      it 'returns max when only max is present' do
        position_assignment.min_estimated_energy = nil
        position_assignment.max_estimated_energy = 50
        expect(position_assignment.anticipated_energy_percentage).to eq(50)
      end

      it 'returns nil when both are nil' do
        position_assignment.min_estimated_energy = nil
        position_assignment.max_estimated_energy = nil
        expect(position_assignment.anticipated_energy_percentage).to be_nil
      end

      it 'handles equal min and max values' do
        position_assignment.min_estimated_energy = 50
        position_assignment.max_estimated_energy = 50
        expect(position_assignment.anticipated_energy_percentage).to eq(50)
      end
    end
  end
end 