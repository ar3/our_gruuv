require 'rails_helper'

RSpec.describe Organizations::PublicMaapHelper, type: :helper do
  describe '#build_organization_hierarchy' do
    let(:company) { create(:organization, :company, name: 'Company') }
    let(:department1) { create(:department, company: company, name: 'Department 1') }
    let(:department2) { create(:department, company: company, name: 'Department 2') }
    let(:sub_department) { create(:department, company: company, parent_department: department1, name: 'Sub Department') }
    let(:team1) { create(:team, company: company, name: 'Team 1') }
    let(:team2) { create(:team, company: company, name: 'Team 2') }

    it 'returns empty array for nil company' do
      expect(helper.build_organization_hierarchy(nil)).to eq([])
    end

    it 'returns empty array for non-company organization' do
      expect(helper.build_organization_hierarchy(department1)).to eq([])
    end

    it 'includes companies and departments' do
      company
      department1
      department2
      
      hierarchy = helper.build_organization_hierarchy(company)
      
      org_ids = hierarchy.map { |item| item[:organization].id }
      expect(org_ids).to include(department1.id, department2.id)
    end

    it 'excludes teams' do
      company
      department1
      department2
      team1
      team2
      
      hierarchy = helper.build_organization_hierarchy(company)
      
      org_ids = hierarchy.map { |item| item[:organization].id }
      expect(org_ids).not_to include(team1.id, team2.id)
    end

    it 'includes nested departments' do
      company
      department1
      sub_department
      team1
      
      hierarchy = helper.build_organization_hierarchy(company)
      
      dept1_item = hierarchy.find { |item| item[:organization].id == department1.id }
      expect(dept1_item).to be_present
      
      child_org_ids = dept1_item[:children].map { |item| item[:organization].id }
      expect(child_org_ids).to include(sub_department.id)
      expect(child_org_ids).not_to include(team1.id)
    end

    it 'sets correct level for top-level departments' do
      company
      department1
      
      hierarchy = helper.build_organization_hierarchy(company)
      
      dept1_item = hierarchy.find { |item| item[:organization].id == department1.id }
      expect(dept1_item[:level]).to eq(0)
    end

    it 'sets correct level for nested departments' do
      company
      department1
      sub_department
      
      hierarchy = helper.build_organization_hierarchy(company)
      
      dept1_item = hierarchy.find { |item| item[:organization].id == department1.id }
      sub_dept_item = dept1_item[:children].find { |item| item[:organization].id == sub_department.id }
      expect(sub_dept_item[:level]).to eq(1)
    end

    it 'handles deep nesting' do
      company
      department1
      sub_department
      
      deep_dept = create(:department, company: company, parent_department: sub_department, name: 'Deep Department')
      
      hierarchy = helper.build_organization_hierarchy(company)
      dept1_item = hierarchy.find { |item| item[:organization].id == department1.id }
      sub_dept_item = dept1_item[:children].find { |item| item[:organization].id == sub_department.id }
      deep_dept_item = sub_dept_item[:children].find { |item| item[:organization].id == deep_dept.id }
      
      expect(deep_dept_item).to be_present
      expect(deep_dept_item[:level]).to eq(2)
    end
  end
end

