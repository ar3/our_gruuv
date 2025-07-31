require 'rails_helper'

RSpec.describe PositionType, type: :model do
  let(:company) { create(:organization, type: 'Company') }
  let(:department) { create(:organization, type: 'Department') }
  let(:team) { create(:organization, type: 'Team') }
  let(:position_major_level) { create(:position_major_level) }
  let(:position_type) { create(:position_type, organization: company, position_major_level: position_major_level) }

  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(position_type).to be_valid
    end

    it 'requires organization' do
      position_type.organization = nil
      expect(position_type).not_to be_valid
    end

    it 'requires position_major_level' do
      position_type.position_major_level = nil
      expect(position_type).not_to be_valid
    end

    it 'requires external_title' do
      position_type.external_title = nil
      expect(position_type).not_to be_valid
    end

    it 'allows blank alternative_titles' do
      position_type.alternative_titles = nil
      expect(position_type).to be_valid
    end

    it 'allows blank position_summary' do
      position_type.position_summary = nil
      expect(position_type).to be_valid
    end

    describe 'organization type validation' do
      it 'allows company organizations' do
        position_type.organization = company
        expect(position_type).to be_valid
      end

      it 'allows department organizations' do
        position_type.organization = department
        expect(position_type).to be_valid
      end

      it 'rejects team organizations' do
        position_type.organization = team
        expect(position_type).not_to be_valid
        expect(position_type.errors[:organization]).to include('must be a company or department')
      end
    end

    describe 'composite uniqueness' do
      it 'allows same external_title with different organizations' do
        other_company = create(:organization, type: 'Company')
        create(:position_type, organization: company, position_major_level: position_major_level, external_title: 'Software Engineer')
        
        new_position_type = build(:position_type, organization: other_company, position_major_level: position_major_level, external_title: 'Software Engineer')
        expect(new_position_type).to be_valid
      end

      it 'allows same external_title with different position_major_levels' do
        other_level = create(:position_major_level)
        create(:position_type, organization: company, position_major_level: position_major_level, external_title: 'Software Engineer')
        
        new_position_type = build(:position_type, organization: company, position_major_level: other_level, external_title: 'Software Engineer')
        expect(new_position_type).to be_valid
      end

      it 'prevents duplicate external_title within same organization and level' do
        create(:position_type, organization: company, position_major_level: position_major_level, external_title: 'Software Engineer')
        
        duplicate = build(:position_type, organization: company, position_major_level: position_major_level, external_title: 'Software Engineer')
        expect(duplicate).not_to be_valid
      end
    end
  end

  describe 'associations' do
    it 'belongs to an organization' do
      expect(position_type.organization).to eq(company)
    end

    it 'belongs to a position_major_level' do
      expect(position_type.position_major_level).to eq(position_major_level)
    end

    it 'has one published external reference' do
      expect(position_type.published_external_reference).to be_nil
    end

    it 'has one draft external reference' do
      expect(position_type.draft_external_reference).to be_nil
    end
  end

  describe 'scopes' do
    it 'orders by external_title' do
      type1 = create(:position_type, external_title: 'Zebra')
      type2 = create(:position_type, external_title: 'Alpha')
      type3 = create(:position_type, external_title: 'Beta')
      
      expect(PositionType.ordered).to eq([type2, type3, type1])
    end
  end

  describe 'instance methods' do
    it 'returns display name' do
      expect(position_type.display_name).to eq(position_type.external_title)
    end

    it 'returns published URL' do
      expect(position_type.published_url).to be_nil
    end

    it 'returns draft URL' do
      expect(position_type.draft_url).to be_nil
    end
  end
end 