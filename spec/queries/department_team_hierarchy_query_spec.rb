require 'rails_helper'

# Uses Department model (Organization no longer has parent/children).
RSpec.describe DepartmentTeamHierarchyQuery do
  let(:company) { create(:organization, :company) }
  let(:department1) { create(:department, company: company, name: 'Dept 1') }
  let(:department2) { create(:department, company: company, name: 'Dept 2') }
  let(:nested_dept1) { create(:department, company: company, parent_department: department1, name: 'Nested Dept 1') }
  let(:nested_dept2) { create(:department, company: company, parent_department: department1, name: 'Nested Dept 2') }
  let(:nested_dept3) { create(:department, company: company, parent_department: department2, name: 'Nested Dept 3') }

  describe '#call' do
    it 'returns empty array when organization has no children' do
      query = described_class.new(organization: company)
      result = query.call
      expect(result).to be_empty
    end

    it 'builds hierarchy with correct structure' do
      department1
      nested_dept1
      
      query = described_class.new(organization: company)
      result = query.call
      
      expect(result.length).to eq(1)
      expect(result.first[:organization].id).to eq(department1.id)
      expect(result.first[:children].length).to eq(1)
      expect(result.first[:children].first[:organization].id).to eq(nested_dept1.id)
    end

    it 'calculates departments_count correctly' do
      department1
      department2
      nested_dept1
      nested_dept2
      nested_dept3
      
      query = described_class.new(organization: company)
      result = query.call
      
      dept1_node = result.find { |n| n[:organization].id == department1.id }
      expect(dept1_node[:departments_count]).to eq(2) # nested_dept1 and nested_dept2
      
      dept2_node = result.find { |n| n[:organization].id == department2.id }
      expect(dept2_node[:departments_count]).to eq(1) # nested_dept3
    end

    it 'excludes archived organizations' do
      archived_dept = create(:department, company: company, deleted_at: Time.current)
      department1
      
      query = described_class.new(organization: company)
      result = query.call
      
      expect(result.map { |n| n[:organization].id }).to include(department1.id)
      expect(result.map { |n| n[:organization].id }).not_to include(archived_dept.id)
    end
  end
end

