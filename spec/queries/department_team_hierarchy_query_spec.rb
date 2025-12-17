require 'rails_helper'

RSpec.describe DepartmentTeamHierarchyQuery do
  let(:company) { create(:organization, :company) }
  let(:department1) { create(:organization, :department, parent: company, name: 'Dept 1') }
  let(:department2) { create(:organization, :department, parent: company, name: 'Dept 2') }
  let(:team1) { create(:organization, :team, parent: department1, name: 'Team 1') }
  let(:team2) { create(:organization, :team, parent: department1, name: 'Team 2') }
  let(:team3) { create(:organization, :team, parent: department2, name: 'Team 3') }

  describe '#call' do
    it 'returns empty array when organization has no children' do
      query = described_class.new(organization: company)
      result = query.call
      expect(result).to be_empty
    end

    it 'builds hierarchy with correct structure' do
      department1
      team1
      
      query = described_class.new(organization: company)
      result = query.call
      
      expect(result.length).to eq(1)
      expect(result.first[:organization].id).to eq(department1.id)
      expect(result.first[:children].length).to eq(1)
      expect(result.first[:children].first[:organization].id).to eq(team1.id)
    end

    it 'calculates counts correctly' do
      department1
      department2
      team1
      team2
      team3
      
      query = described_class.new(organization: company)
      result = query.call
      
      dept1_node = result.find { |n| n[:organization].id == department1.id }
      expect(dept1_node[:departments_count]).to eq(0)
      expect(dept1_node[:teams_count]).to eq(2)
      
      dept2_node = result.find { |n| n[:organization].id == department2.id }
      expect(dept2_node[:departments_count]).to eq(0)
      expect(dept2_node[:teams_count]).to eq(1)
    end

    it 'excludes archived organizations' do
      archived_dept = create(:organization, :department, parent: company, deleted_at: Time.current)
      department1
      
      query = described_class.new(organization: company)
      result = query.call
      
      expect(result.map { |n| n[:organization].id }).to include(department1.id)
      expect(result.map { |n| n[:organization].id }).not_to include(archived_dept.id)
    end
  end
end

