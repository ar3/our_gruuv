require 'rails_helper'

RSpec.describe Title, type: :model do
  let(:company) { create(:organization) }
  let(:department) { create(:department, company: company) }
  let(:position_major_level) { create(:position_major_level) }
  let(:title) { create(:title, company: company, position_major_level: position_major_level) }

  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(title).to be_valid
    end

    it 'requires company' do
      title.company = nil
      expect(title).not_to be_valid
    end

    it 'requires position_major_level' do
      title.position_major_level = nil
      expect(title).not_to be_valid
    end

    it 'requires external_title' do
      title.external_title = nil
      expect(title).not_to be_valid
    end

    it 'allows blank alternative_titles' do
      title.alternative_titles = nil
      expect(title).to be_valid
    end

    it 'allows blank position_summary' do
      title.position_summary = nil
      expect(title).to be_valid
    end

    describe 'company type validation' do
      it 'allows organizations' do
        expect(title).to be_valid
        expect(title.company).to be_an(Organization)
      end
    end

    describe 'department validation' do
      it 'is valid with a department from the same company' do
        title.department = department
        expect(title).to be_valid
      end

      it 'is invalid with a department from a different company' do
        other_company = create(:organization)
        other_department = create(:department, company: other_company)
        title.department = other_department
        expect(title).not_to be_valid
        expect(title.errors[:department]).to include('must belong to the same company')
      end
    end

    describe 'composite uniqueness' do
      it 'allows same external_title with different companies' do
        other_company = create(:organization)
        create(:title, company: company, position_major_level: position_major_level, external_title: 'Software Engineer')
        
        new_title = build(:title, company: other_company, position_major_level: position_major_level, external_title: 'Software Engineer')
        expect(new_title).to be_valid
      end

      it 'allows same external_title with different position_major_levels' do
        other_level = create(:position_major_level)
        create(:title, company: company, position_major_level: position_major_level, external_title: 'Software Engineer')
        
        new_title = build(:title, company: company, position_major_level: other_level, external_title: 'Software Engineer')
        expect(new_title).to be_valid
      end

      it 'prevents duplicate external_title within same company and level' do
        create(:title, company: company, position_major_level: position_major_level, external_title: 'Software Engineer')
        
        duplicate = build(:title, company: company, position_major_level: position_major_level, external_title: 'Software Engineer')
        expect(duplicate).not_to be_valid
      end
    end
  end

  describe 'associations' do
    it 'belongs to a company' do
      expect(title.company_id).to eq(company.id)
    end

    it 'belongs to a position_major_level' do
      expect(title.position_major_level).to eq(position_major_level)
    end

    it 'belongs to a department optionally' do
      title.department = department
      title.save!
      expect(title.department).to eq(department)
    end

    it 'has one published external reference' do
      expect(title.published_external_reference).to be_nil
    end

    it 'has one draft external reference' do
      expect(title.draft_external_reference).to be_nil
    end
  end

  describe 'scopes' do
    it 'orders by external_title' do
      type1 = create(:title, external_title: 'Zebra')
      type2 = create(:title, external_title: 'Alpha')
      type3 = create(:title, external_title: 'Beta')
      
      expect(Title.ordered).to eq([type2, type3, type1])
    end

    describe '.for_company' do
      let(:other_company) { create(:organization) }
      let!(:title1) { create(:title, company: company) }
      let!(:title2) { create(:title, company: other_company) }

      it 'returns titles for specific company' do
        expect(Title.for_company(company)).to include(title1)
        expect(Title.for_company(company)).not_to include(title2)
      end
    end

    describe '.for_department' do
      let!(:dept_title) { create(:title, company: company, department: department) }
      let!(:no_dept_title) { create(:title, company: company, department: nil) }

      it 'returns titles for specific department' do
        expect(Title.for_department(department)).to include(dept_title)
        expect(Title.for_department(department)).not_to include(no_dept_title)
      end
    end
  end

  describe 'instance methods' do
    it 'returns display name' do
      expect(title.display_name).to eq(title.external_title)
    end

    it 'returns published URL' do
      expect(title.published_url).to be_nil
    end

    it 'returns draft URL' do
      expect(title.draft_url).to be_nil
    end
  end
end
