require 'rails_helper'

RSpec.describe Aspiration, type: :model do
  let(:company) { create(:company) }
  let(:aspiration) { create(:aspiration, company: company, name: 'Test Aspiration') }

  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(aspiration).to be_valid
    end

    it 'requires a name' do
      aspiration.name = nil
      expect(aspiration).not_to be_valid
      expect(aspiration.errors[:name]).to include("can't be blank")
    end

    it 'requires a sort_order' do
      aspiration.sort_order = nil
      expect(aspiration).not_to be_valid
      expect(aspiration.errors[:sort_order]).to include("can't be blank")
    end

    it 'enforces unique names within the same company' do
      create(:aspiration, company: company, name: 'Unique Name')
      
      duplicate = build(:aspiration, company: company, name: 'Unique Name')
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to include('has already been taken')
    end

    it 'allows same name in different companies' do
      other_company = create(:company)
      create(:aspiration, company: company, name: 'Shared Name')
      
      other_aspiration = build(:aspiration, company: other_company, name: 'Shared Name')
      expect(other_aspiration).to be_valid
    end

    describe 'department_must_belong_to_company' do
      it 'is valid when department belongs to the same company' do
        department = create(:department, company: company)
        aspiration = build(:aspiration, company: company, department: department)
        expect(aspiration).to be_valid
      end

      it 'is invalid when department belongs to a different company' do
        other_company = create(:company)
        department = create(:department, company: other_company)
        aspiration = build(:aspiration, company: company, department: department)
        expect(aspiration).not_to be_valid
        expect(aspiration.errors[:department]).to include('must belong to the same company')
      end
    end
  end

  describe 'associations' do
    it 'belongs to a company' do
      expect(aspiration.company_id).to eq(company.id)
    end

    it 'belongs to a department optionally' do
      department = create(:department, company: company)
      aspiration.department = department
      aspiration.save!
      expect(aspiration.department).to eq(department)
    end

    it 'has many observation_ratings' do
      expect(aspiration.observation_ratings).to be_empty
    end

    it 'has many observations through observation_ratings' do
      expect(aspiration.observations).to be_empty
    end
  end

  describe 'scopes' do
    it 'orders by sort_order then name' do
      asp1 = create(:aspiration, company: company, name: 'Zebra', sort_order: 2)
      asp2 = create(:aspiration, company: company, name: 'Alpha', sort_order: 1)
      asp3 = create(:aspiration, company: company, name: 'Beta', sort_order: 1)
      
      expect(Aspiration.ordered).to eq([asp2, asp3, asp1])
    end

    describe '.for_company' do
      let(:other_company) { create(:company) }
      let!(:asp1) { create(:aspiration, company: company) }
      let!(:asp2) { create(:aspiration, company: other_company) }

      it 'returns aspirations for specific company' do
        expect(Aspiration.for_company(company)).to include(asp1)
        expect(Aspiration.for_company(company)).not_to include(asp2)
      end
    end

    describe '.for_department' do
      let(:department) { create(:department, company: company) }
      let!(:dept_asp) { create(:aspiration, company: company, department: department) }
      let!(:no_dept_asp) { create(:aspiration, company: company, department: nil) }

      it 'returns aspirations for specific department' do
        expect(Aspiration.for_department(department)).to include(dept_asp)
        expect(Aspiration.for_department(department)).not_to include(no_dept_asp)
      end
    end
  end

  describe 'soft delete' do
    it 'soft deletes an aspiration' do
      aspiration.soft_delete!
      expect(aspiration.deleted?).to be true
      expect(aspiration.deleted_at).to be_present
    end

    it 'excludes soft deleted aspirations by default' do
      aspiration.soft_delete!
      expect(Aspiration.all).not_to include(aspiration)
    end

    it 'includes soft deleted with with_deleted scope' do
      aspiration.soft_delete!
      expect(Aspiration.with_deleted).to include(aspiration)
    end
  end

  describe '#to_param' do
    it 'returns id-name-parameterized format based on name' do
      aspiration = create(:aspiration, company: company, name: 'Technical Excellence')
      expect(aspiration.to_param).to eq("#{aspiration.id}-technical-excellence")
    end

    it 'handles special characters in name' do
      aspiration = create(:aspiration, company: company, name: 'Team & Collaboration!')
      expect(aspiration.to_param).to eq("#{aspiration.id}-team-collaboration")
    end
  end

  describe '.find_by_param' do
    let(:aspiration) { create(:aspiration, company: company, name: 'Test Aspiration') }

    it 'finds by numeric id' do
      expect(Aspiration.find_by_param(aspiration.id.to_s)).to eq(aspiration)
    end

    it 'finds by id-name-parameterized format' do
      param = "#{aspiration.id}-test-aspiration"
      expect(Aspiration.find_by_param(param)).to eq(aspiration)
    end

    it 'extracts id from id-name format' do
      param = "#{aspiration.id}-some-other-name"
      expect(Aspiration.find_by_param(param)).to eq(aspiration)
    end

    it 'raises error for invalid id' do
      expect {
        Aspiration.find_by_param('999999')
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
