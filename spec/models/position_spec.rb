require 'rails_helper'

RSpec.describe Position, type: :model do
  let(:company) { create(:organization, type: 'Company') }
  let(:position_major_level) { create(:position_major_level) }
  let(:position_level) { create(:position_level, position_major_level: position_major_level) }
  let(:position_type) { create(:position_type, organization: company, position_major_level: position_major_level) }
  let(:position) { create(:position, position_type: position_type, position_level: position_level) }

  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(position).to be_valid
    end

    it 'requires position_type' do
      position.position_type = nil
      expect(position).not_to be_valid
    end

    it 'requires position_level' do
      position.position_level = nil
      expect(position).not_to be_valid
    end

    it 'allows blank position_summary' do
      position.position_summary = nil
      expect(position).to be_valid
    end

    describe 'position_level validation' do
      it 'allows position_level from the same major level' do
        expect(position).to be_valid
      end

      it 'rejects position_level from different major level' do
        other_major_level = create(:position_major_level)
        other_level = create(:position_level, position_major_level: other_major_level)
        position.position_level = other_level
        expect(position).not_to be_valid
      end
    end

    describe 'composite uniqueness' do
      it 'prevents duplicate position_type and position_level combination' do
        create(:position, position_type: position_type, position_level: position_level)
        
        duplicate = build(:position, position_type: position_type, position_level: position_level)
        expect(duplicate).not_to be_valid
      end

      it 'allows same position_level with different position_type' do
        other_position_type = create(:position_type, external_title: 'Different Title', organization: company, position_major_level: position_major_level)
        create(:position, position_type: position_type, position_level: position_level)
        
        new_position = build(:position, position_type: other_position_type, position_level: position_level)
        expect(new_position).to be_valid
      end
    end
  end

  describe 'associations' do
    it 'belongs to a position_type' do
      expect(position.position_type).to eq(position_type)
    end

    it 'belongs to a position_level' do
      expect(position.position_level).to eq(position_level)
    end

    it 'has many position_assignments' do
      expect(position.position_assignments).to be_empty
    end

    it 'has many assignments through position_assignments' do
      expect(position.assignments).to be_empty
    end

    it 'has one published external reference' do
      expect(position.published_external_reference).to be_nil
    end

    it 'has one draft external reference' do
      expect(position.draft_external_reference).to be_nil
    end
  end

  describe 'scopes' do
    it 'orders by position_type and position_level' do
      type1 = create(:position_type, external_title: 'Zebra', organization: company, position_major_level: position_major_level)
      type2 = create(:position_type, external_title: 'Alpha', organization: company, position_major_level: position_major_level)
      
      level1 = create(:position_level, level: '2.0', position_major_level: position_major_level)
      level2 = create(:position_level, level: '1.0', position_major_level: position_major_level)
      
      pos1 = create(:position, position_type: type1, position_level: level1)
      pos2 = create(:position, position_type: type2, position_level: level2)
      pos3 = create(:position, position_type: type2, position_level: level1)
      
      expect(Position.ordered).to eq([pos2, pos3, pos1])
    end

    it 'filters by company' do
      other_company = create(:organization, type: 'Company')
      other_position_type = create(:position_type, organization: other_company, position_major_level: position_major_level)
      other_position = create(:position, position_type: other_position_type, position_level: position_level)
      
      expect(Position.for_company(company)).to include(position)
      expect(Position.for_company(company)).not_to include(other_position)
    end
  end

  describe 'instance methods' do
    it 'returns display name with version' do
      expect(position.display_name).to eq("#{position_type.external_title} - #{position_level.level_name} v#{position.semantic_version}")
    end

    it 'returns company' do
      expect(position.company).to eq(company)
    end

    describe 'assignment methods' do
      let(:position_with_assignments) { create(:position, :with_assignments, position_type: position_type, position_level: position_level) }

      it 'returns required assignments' do
        expect(position_with_assignments.required_assignments.count).to eq(2)
      end

      it 'returns suggested assignments' do
        expect(position_with_assignments.suggested_assignments.count).to eq(1)
      end

      it 'returns required assignments count' do
        expect(position_with_assignments.required_assignments_count).to eq(2)
      end

      it 'returns suggested assignments count' do
        expect(position_with_assignments.suggested_assignments_count).to eq(1)
      end
    end

    describe 'external reference methods' do
      let(:position_with_refs) { create(:position, :with_external_references, position_type: position_type, position_level: position_level) }

      it 'returns published URL' do
        expect(position_with_refs.published_url).to eq("https://docs.google.com/document/d/published-example")
      end

      it 'returns draft URL' do
        expect(position_with_refs.draft_url).to eq("https://docs.google.com/document/d/draft-example")
      end

      it 'returns nil for missing references' do
        expect(position.published_url).to be_nil
        expect(position.draft_url).to be_nil
      end
    end
  end

  describe '#to_param' do
    it 'returns id-name-parameterized format based on display_name' do
      position_type = create(:position_type, external_title: 'Software Engineer', organization: company, position_major_level: position_major_level)
      position_level = create(:position_level, level: '1.2', position_major_level: position_major_level)
      position = create(:position, position_type: position_type, position_level: position_level)
      
      expected_param = "#{position.id}-#{position.display_name.parameterize}"
      expect(position.to_param).to eq(expected_param)
    end
  end

  describe '.find_by_param' do
    let(:position) { create(:position, position_type: position_type, position_level: position_level) }

    it 'finds by numeric id' do
      expect(Position.find_by_param(position.id.to_s)).to eq(position)
    end

    it 'finds by id-name-parameterized format' do
      param = "#{position.id}-#{position.display_name.parameterize}"
      expect(Position.find_by_param(param)).to eq(position)
    end

    it 'extracts id from id-name format' do
      param = "#{position.id}-some-other-name"
      expect(Position.find_by_param(param)).to eq(position)
    end

    it 'raises error for invalid id' do
      expect {
        Position.find_by_param('999999')
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end 