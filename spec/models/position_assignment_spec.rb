require 'rails_helper'

RSpec.describe PositionAssignment, type: :model do
  let(:company) { create(:organization, type: 'Company') }
  let(:position_major_level) { create(:position_major_level) }
  let(:position_level) { create(:position_level, position_major_level: position_major_level) }
  let(:position_type) { create(:position_type, organization: company, position_major_level: position_major_level) }
  let(:position) { create(:position, position_type: position_type, position_level: position_level) }
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

    describe 'uniqueness' do
      it 'prevents duplicate position and assignment combination' do
        create(:position_assignment, position: position, assignment: assignment)
        
        duplicate = build(:position_assignment, position: position, assignment: assignment)
        expect(duplicate).not_to be_valid
      end

      it 'allows same assignment with different position' do
        other_position = create(:position, position_type: position_type, position_level: create(:position_level, position_major_level: position_major_level))
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
  end
end 