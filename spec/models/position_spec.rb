require 'rails_helper'

RSpec.describe Position, type: :model do
  let(:company) { create(:organization) }
  let(:person) { create(:person) }
  let(:position_major_level) { create(:position_major_level) }
  let(:position_level) { create(:position_level, position_major_level: position_major_level) }
  let(:title) { create(:title, company: company, position_major_level: position_major_level) }
  let(:position) { create(:position, title: title, position_level: position_level) }

  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(position).to be_valid
    end

    it 'requires title' do
      position.title = nil
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
      it 'prevents duplicate title and position_level combination' do
        create(:position, title: title, position_level: position_level)
        
        duplicate = build(:position, title: title, position_level: position_level)
        expect(duplicate).not_to be_valid
      end

      it 'allows same position_level with different title' do
        other_title = create(:title, external_title: 'Different Title', company: company, position_major_level: position_major_level)
        create(:position, title: title, position_level: position_level)
        
        new_position = build(:position, title: other_title, position_level: position_level)
        expect(new_position).to be_valid
      end
    end
  end

  describe 'associations' do
    it 'belongs to a title' do
      expect(position.title).to eq(title)
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

  describe 'archiving' do
    describe '.unarchived and .archived' do
      it 'unarchived returns only positions with nil deleted_at' do
        p1 = create(:position, title: title, position_level: position_level, deleted_at: nil)
        p2 = create(:position, title: title, position_level: create(:position_level, position_major_level: position_major_level))
        p2.update_columns(deleted_at: 1.day.ago)
        expect(Position.unarchived).to include(p1)
        expect(Position.unarchived).not_to include(p2)
      end

      it 'archived returns only positions with deleted_at set' do
        p1 = create(:position, title: title, position_level: position_level)
        p2 = create(:position, title: title, position_level: create(:position_level, position_major_level: position_major_level))
        p2.update_columns(deleted_at: 1.day.ago)
        expect(Position.archived).to include(p2)
        expect(Position.archived).not_to include(p1)
      end
    end

    describe '#archived?' do
      it 'returns false when deleted_at is nil' do
        expect(position.archived?).to be false
      end

      it 'returns true when deleted_at is set' do
        position.update_columns(deleted_at: 1.day.ago)
        expect(position.reload.archived?).to be true
      end
    end

    describe '#archive!' do
      it 'sets deleted_at to current time' do
        position.archive!
        expect(position.reload.deleted_at).to be_present
      end
    end

    describe '#restore!' do
      it 'clears deleted_at' do
        position.update_columns(deleted_at: 1.day.ago)
        position.restore!
        expect(position.reload.deleted_at).to be_nil
      end
    end

    describe '#archivable?' do
      it 'returns true when no position_assignments, position_abilities, or active employment_tenures' do
        expect(position.archivable?).to be true
      end

      it 'returns false when position has position_assignments' do
        assignment = create(:assignment, company: company)
        create(:position_assignment, position: position, assignment: assignment, assignment_type: 'required')
        expect(position.reload.archivable?).to be false
      end

      it 'returns false when position has position_abilities' do
        ability = create(:ability, company: company, created_by: person, updated_by: person)
        create(:position_ability, position: position, ability: ability, milestone_level: 1)
        expect(position.reload.archivable?).to be false
      end

      it 'returns false when position has active employment_tenures' do
        teammate = create(:company_teammate, person: person, organization: company)
        et = build(:employment_tenure, company_teammate: teammate, company: company, started_at: 1.month.ago, ended_at: nil)
        et.position = position
        et.save!
        expect(position.reload.archivable?).to be false
      end

      it 'returns true when employment_tenures are ended' do
        teammate = create(:company_teammate, person: person, organization: company)
        et = build(:employment_tenure, company_teammate: teammate, company: company, started_at: 2.months.ago, ended_at: 1.month.ago)
        et.position = position
        et.save!
        expect(position.reload.archivable?).to be true
      end
    end
  end

  describe 'scopes' do
    it 'orders by title and position_level' do
      type1 = create(:title, external_title: 'Zebra', company: company, position_major_level: position_major_level)
      type2 = create(:title, external_title: 'Alpha', company: company, position_major_level: position_major_level)
      
      level1 = create(:position_level, level: '2.0', position_major_level: position_major_level)
      level2 = create(:position_level, level: '1.0', position_major_level: position_major_level)
      
      pos1 = create(:position, title: type1, position_level: level1)
      pos2 = create(:position, title: type2, position_level: level2)
      pos3 = create(:position, title: type2, position_level: level1)
      
      expect(Position.ordered).to eq([pos2, pos3, pos1])
    end

    it 'filters by company' do
      other_company = create(:organization)
      other_title = create(:title, company: other_company, position_major_level: position_major_level)
      other_position = create(:position, title: other_title, position_level: position_level)
      
      expect(Position.for_company(company)).to include(position)
      expect(Position.for_company(company)).not_to include(other_position)
    end
  end

  describe 'instance methods' do
    it 'returns display name without version' do
      expect(position.display_name).to eq("#{title.external_title} - #{position_level.level}")
    end
    
    it 'returns display name with version' do
      expect(position.display_name_with_version).to eq("#{title.external_title} - #{position_level.level} v#{position.semantic_version}")
    end

    it 'returns company' do
      expect(position.company).to eq(company)
    end

    describe 'assignment methods' do
      let(:position_with_assignments) { create(:position, :with_assignments, title: title, position_level: position_level) }

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
      let(:position_with_refs) { create(:position, :with_external_references, title: title, position_level: position_level) }

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
      title = create(:title, external_title: 'Software Engineer', company: company, position_major_level: position_major_level)
      position_level = create(:position_level, level: '1.2', position_major_level: position_major_level)
      position = create(:position, title: title, position_level: position_level)
      
      expected_param = "#{position.id}-#{position.display_name.parameterize}"
      expect(position.to_param).to eq(expected_param)
    end
  end

  describe '.find_by_param' do
    let(:position) { create(:position, title: title, position_level: position_level) }

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