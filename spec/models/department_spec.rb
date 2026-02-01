require 'rails_helper'

RSpec.describe Department, type: :model do
  let(:company) { create(:company) }
  let(:department) { create(:department, company: company) }

  describe 'associations' do
    it { should belong_to(:company).class_name('Organization') }
    it { should belong_to(:parent_department).class_name('Department').optional }
    it { should have_many(:child_departments).class_name('Department').with_foreign_key('parent_department_id') }
    it { should have_many(:abilities) }
    it { should have_many(:aspirations) }
    it { should have_many(:titles) }
    it { should have_many(:assignments) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:company) }

    it 'validates that parent_department belongs to the same company' do
      other_company = create(:company)
      other_department = create(:department, company: other_company)
      
      department.parent_department = other_department
      expect(department).not_to be_valid
      expect(department.errors[:parent_department]).to include('must belong to the same company')
    end
  end

  describe 'scopes' do
    let!(:active_department) { create(:department, company: company) }
    let!(:archived_department) { create(:department, company: company, deleted_at: Time.current) }
    let!(:root_department) { create(:department, company: company, parent_department: nil) }
    let!(:child_department) { create(:department, company: company, parent_department: root_department) }

    describe '.active' do
      it 'returns only departments without deleted_at' do
        expect(Department.active).to include(active_department, root_department, child_department)
        expect(Department.active).not_to include(archived_department)
      end
    end

    describe '.archived' do
      it 'returns only departments with deleted_at' do
        expect(Department.archived).to include(archived_department)
        expect(Department.archived).not_to include(active_department)
      end
    end

    describe '.root_departments' do
      it 'returns only departments without parent_department' do
        expect(Department.root_departments).to include(root_department)
        expect(Department.root_departments).not_to include(child_department)
      end
    end

    describe '.for_company' do
      let(:other_company) { create(:company) }
      let!(:other_department) { create(:department, company: other_company) }

      it 'returns only departments for the specified company' do
        expect(Department.for_company(company)).to include(active_department, root_department, child_department)
        expect(Department.for_company(company)).not_to include(other_department)
      end
    end
  end

  describe 'hierarchy methods' do
    let(:root_dept) { create(:department, company: company, name: 'Root') }
    let(:child_dept) { create(:department, company: company, parent_department: root_dept, name: 'Child') }
    let(:grandchild_dept) { create(:department, company: company, parent_department: child_dept, name: 'Grandchild') }

    describe '#self_and_descendants' do
      it 'returns self and all descendants' do
        grandchild_dept # ensure it exists
        
        result = root_dept.self_and_descendants
        expect(result).to include(root_dept, child_dept, grandchild_dept)
      end

      it 'returns only self for leaf nodes' do
        expect(grandchild_dept.self_and_descendants).to eq([grandchild_dept])
      end
    end

    describe '#descendants' do
      it 'returns all descendants' do
        grandchild_dept # ensure it exists
        
        result = root_dept.descendants
        expect(result).to include(child_dept, grandchild_dept)
        expect(result).not_to include(root_dept)
      end
    end

    describe '#ancestors_list' do
      it 'returns all ancestors' do
        grandchild_dept # ensure it exists
        
        expect(grandchild_dept.ancestors_list).to eq([child_dept, root_dept])
      end

      it 'returns empty array for root departments' do
        expect(root_dept.ancestors_list).to eq([])
      end
    end

    describe '#ancestry_depth' do
      it 'returns 0 for root departments' do
        expect(root_dept.ancestry_depth).to eq(0)
      end

      it 'returns correct depth for nested departments' do
        expect(child_dept.ancestry_depth).to eq(1)
        expect(grandchild_dept.ancestry_depth).to eq(2)
      end
    end

    describe '#root?' do
      it 'returns true for root departments' do
        expect(root_dept.root?).to be true
      end

      it 'returns false for child departments' do
        expect(child_dept.root?).to be false
      end
    end

    describe '#display_name' do
      it 'returns just the name for root departments' do
        expect(root_dept.display_name).to eq('Root')
      end

      it 'returns hierarchical path for child departments' do
        expect(child_dept.display_name).to eq('Root > Child')
        expect(grandchild_dept.display_name).to eq('Root > Child > Grandchild')
      end
    end
  end

  describe 'soft delete' do
    it 'soft deletes the department' do
      department.soft_delete!
      
      expect(department.deleted_at).to be_present
      expect(department.archived?).to be true
    end

    it 'can be restored' do
      department.soft_delete!
      department.restore!
      
      expect(department.deleted_at).to be_nil
      expect(department.archived?).to be false
    end
  end

  describe '#to_param' do
    it 'returns id-name format' do
      department = create(:department, company: company, name: 'Engineering Team')
      expect(department.to_param).to eq("#{department.id}-engineering-team")
    end
  end

  describe '.find_by_param' do
    let!(:department) { create(:department, company: company, name: 'Engineering') }

    it 'finds department by id' do
      expect(Department.find_by_param(department.id.to_s)).to eq(department)
    end

    it 'finds department by id-name format' do
      expect(Department.find_by_param("#{department.id}-engineering")).to eq(department)
    end

    it 'returns nil for non-existent id' do
      expect(Department.find_by_param('999999')).to be_nil
    end
  end

  describe 'type checking helpers' do
    it 'returns true for department?' do
      expect(department.department?).to be true
    end

    it 'returns false for team?' do
      expect(department.team?).to be false
    end

    it 'returns false for company?' do
      expect(department.company?).to be false
    end
  end
end
