require 'rails_helper'

RSpec.describe AssignmentSupplyRelationship, type: :model do
  let(:company) { create(:organization, :company) }
  let(:supplier_assignment) { create(:assignment, company: company) }
  let(:consumer_assignment) { create(:assignment, company: company) }

  describe 'validations' do
    it 'is valid with valid attributes' do
      relationship = AssignmentSupplyRelationship.new(
        supplier_assignment: supplier_assignment,
        consumer_assignment: consumer_assignment
      )
      expect(relationship).to be_valid
    end

    it 'requires supplier_assignment' do
      relationship = AssignmentSupplyRelationship.new(consumer_assignment: consumer_assignment)
      expect(relationship).not_to be_valid
      expect(relationship.errors[:supplier_assignment]).to be_present
    end

    it 'requires consumer_assignment' do
      relationship = AssignmentSupplyRelationship.new(supplier_assignment: supplier_assignment)
      expect(relationship).not_to be_valid
      expect(relationship.errors[:consumer_assignment]).to be_present
    end

    it 'prevents duplicate relationships' do
      AssignmentSupplyRelationship.create!(
        supplier_assignment: supplier_assignment,
        consumer_assignment: consumer_assignment
      )
      
      duplicate = AssignmentSupplyRelationship.new(
        supplier_assignment: supplier_assignment,
        consumer_assignment: consumer_assignment
      )
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:supplier_assignment_id]).to be_present
    end

    it 'prevents self-referential relationships' do
      relationship = AssignmentSupplyRelationship.new(
        supplier_assignment: supplier_assignment,
        consumer_assignment: supplier_assignment
      )
      expect(relationship).not_to be_valid
      expect(relationship.errors[:base]).to include('An assignment cannot be both supplier and consumer of itself')
    end

    it 'requires assignments to be in same company hierarchy' do
      other_company = create(:organization, :company)
      other_assignment = create(:assignment, company: other_company)
      
      relationship = AssignmentSupplyRelationship.new(
        supplier_assignment: supplier_assignment,
        consumer_assignment: other_assignment
      )
      expect(relationship).not_to be_valid
      expect(relationship.errors[:base]).to include('Both assignments must belong to the same company hierarchy')
    end

    it 'allows relationships within same company' do
      relationship = AssignmentSupplyRelationship.new(
        supplier_assignment: supplier_assignment,
        consumer_assignment: consumer_assignment
      )
      expect(relationship).to be_valid
    end

    it 'allows relationships within company hierarchy' do
      department = create(:department, company: company)
      department_assignment = create(:assignment, company: company, department: department)
      
      relationship = AssignmentSupplyRelationship.new(
        supplier_assignment: supplier_assignment,
        consumer_assignment: department_assignment
      )
      expect(relationship).to be_valid
    end
  end

  describe 'associations' do
    it 'belongs to supplier_assignment' do
      relationship = AssignmentSupplyRelationship.create!(
        supplier_assignment: supplier_assignment,
        consumer_assignment: consumer_assignment
      )
      expect(relationship.supplier_assignment).to eq(supplier_assignment)
    end

    it 'belongs to consumer_assignment' do
      relationship = AssignmentSupplyRelationship.create!(
        supplier_assignment: supplier_assignment,
        consumer_assignment: consumer_assignment
      )
      expect(relationship.consumer_assignment).to eq(consumer_assignment)
    end
  end
end
