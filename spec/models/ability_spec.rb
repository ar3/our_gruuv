require 'rails_helper'

RSpec.describe Ability, type: :model do
  let(:company) { create(:company) }
  let(:person) { create(:person) }
  let(:admin) { create(:person, :admin) }

  describe 'associations' do
    it { should belong_to(:company).class_name('Organization') }
    it { should belong_to(:created_by).class_name('Person') }
    it { should belong_to(:updated_by).class_name('Person') }
    it { should have_many(:assignment_abilities) }
    it { should have_many(:assignments).through(:assignment_abilities) }
    it { should belong_to(:department).optional }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:description) }
    it { should validate_presence_of(:semantic_version) }
    it { should belong_to(:created_by).class_name('Person') }
    it { should belong_to(:updated_by).class_name('Person') }

    describe 'milestone descriptions' do
      let(:ability) { create(:ability, company: company, created_by: person, updated_by: person) }

      it 'allows milestone descriptions to be optional' do
        ability.milestone_1_description = nil
        ability.milestone_2_description = nil
        expect(ability).to be_valid
      end

      it 'allows milestone descriptions to be set' do
        ability.milestone_1_description = 'Basic understanding and ability to perform fundamental tasks'
        ability.milestone_3_description = 'Expert level with ability to handle complex situations'
        expect(ability).to be_valid
      end
    end

    it 'validates uniqueness of name within company' do
      create(:ability, name: 'Ruby Programming', company: company)
      duplicate_ability = build(:ability, name: 'Ruby Programming', company: company)
      expect(duplicate_ability).not_to be_valid
      expect(duplicate_ability.errors[:name]).to include('has already been taken')
    end

    it 'allows same name across different companies' do
      other_company = create(:company)
      create(:ability, name: 'Ruby Programming', company: company)
      other_ability = build(:ability, name: 'Ruby Programming', company: other_company)
      expect(other_ability).to be_valid
    end

    describe 'department_must_belong_to_company' do
      it 'is valid when department belongs to the same company' do
        department = create(:department, company: company)
        ability = build(:ability, company: company, department: department)
        expect(ability).to be_valid
      end

      it 'is invalid when department belongs to a different company' do
        other_company = create(:company)
        department = create(:department, company: other_company)
        ability = build(:ability, company: company, department: department)
        expect(ability).not_to be_valid
        expect(ability.errors[:department]).to include('must belong to the same company')
      end
    end
  end

  describe 'versioning' do
    around do |example|
      was_enabled = PaperTrail.enabled?
      was_request_enabled = PaperTrail.request.enabled?
      PaperTrail.enabled = true
      PaperTrail.request.enabled = true
      example.run
    ensure
      PaperTrail.enabled = was_enabled
      PaperTrail.request.enabled = was_request_enabled
    end

    it 'has paper trail enabled' do
      expect(Ability.new).to respond_to(:versions)
    end

    it 'tracks basic version history' do
      ability = create(:ability, company: company, created_by: person, updated_by: person)
      # With PaperTrail enabled, a newly created record has 1 version (creation)
      expect(ability.versions.count).to eq(1)
      
      ability.update!(name: 'Updated Name', updated_by: admin)
      expect(ability.versions.count).to eq(2)
    end
  end

  describe 'semantic versioning' do
    let(:ability) { create(:ability, company: company, created_by: person, updated_by: person) }

    describe '#major_version' do
      it 'extracts major version number from semantic_version' do
        ability.update!(semantic_version: '1.2.3')
        expect(ability.major_version).to eq(1)
      end

      it 'handles version 0 correctly' do
        ability.update!(semantic_version: '0.1.0')
        expect(ability.major_version).to eq(0)
      end

      it 'handles multi-digit major versions' do
        ability.update!(semantic_version: '10.5.2')
        expect(ability.major_version).to eq(10)
      end
    end

    describe '#bump_major_version' do
      it 'increments major version' do
        ability.bump_major_version('Complete rewrite of ability definition')
        expect(ability.semantic_version).to eq('2.0.0')
      end

      it 'resets minor and patch versions' do
        ability.update!(semantic_version: '1.5.3')
        ability.bump_major_version('Breaking change')
        expect(ability.semantic_version).to eq('2.0.0')
      end
    end

    describe '#bump_minor_version' do
      it 'increments minor version' do
        ability.bump_minor_version('Added new competency areas')
        expect(ability.semantic_version).to eq('1.1.0')
      end

      it 'resets patch version' do
        ability.update!(semantic_version: '1.0.3')
        ability.bump_minor_version('Significant change')
        expect(ability.semantic_version).to eq('1.1.0')
      end
    end

    describe '#bump_patch_version' do
      it 'increments patch version' do
        ability.bump_patch_version('Fixed typo in description')
        expect(ability.semantic_version).to eq('1.0.1')
      end
    end
  end

  describe 'scopes' do
    let!(:ability1) { create(:ability, company: company) }
    let!(:ability2) { create(:ability, company: company) }
    let!(:other_company_ability) { create(:ability, company: create(:company)) }

    describe '.for_company' do
      it 'returns abilities for specific company' do
        expect(Ability.for_company(company)).to include(ability1, ability2)
        expect(Ability.for_company(company)).not_to include(other_company_ability)
      end
    end

    describe '.for_department' do
      let(:department) { create(:department, company: company) }
      let!(:dept_ability) { create(:ability, company: company, department: department) }

      it 'returns abilities for specific department' do
        expect(Ability.for_department(department)).to include(dept_ability)
        expect(Ability.for_department(department)).not_to include(ability1, ability2)
      end
    end

    describe '.recent' do
      it 'orders by updated_at descending' do
        ability1.update!(name: 'Updated First')
        ability2.update!(name: 'Updated Second')
        
        expect(Ability.recent.to_a).to eq([ability2, ability1, other_company_ability])
      end
    end
  end

  describe 'instance methods' do
    let(:ability) { create(:ability, company: company, created_by: person, updated_by: person) }

    describe '#current_version?' do
      it 'returns true for latest version' do
        expect(ability.current_version?).to be true
      end

      it 'returns false for older versions' do
        ability.update!(name: 'Updated', updated_by: person)
        expect(ability.current_version?).to be true # Still current since it's the latest
      end
    end

    describe '#deprecated?' do
      it 'returns false for current version' do
        expect(ability.deprecated?).to be false
      end

      it 'returns true for deprecated versions' do
        ability.update!(name: 'Updated', updated_by: person)
        expect(ability.deprecated?).to be false
      end
    end
  end

  describe 'assignment-related methods' do
    let(:ability) { create(:ability, company: company, created_by: person, updated_by: person) }
    let(:assignment1) { create(:assignment, company: company) }
    let(:assignment2) { create(:assignment, company: company, title: 'Different Assignment') }

    describe '#required_by_assignments' do
      it 'returns assignments ordered by milestone level' do
        create(:assignment_ability, assignment: assignment2, ability: ability, milestone_level: 3)
        create(:assignment_ability, assignment: assignment1, ability: ability, milestone_level: 1)

        result = ability.required_by_assignments
        expect(result.map(&:assignment)).to eq([assignment1, assignment2])
      end
    end

    describe '#required_by_assignments_count' do
      it 'returns count of assignments requiring this ability' do
        create(:assignment_ability, assignment: assignment1, ability: ability)
        create(:assignment_ability, assignment: assignment2, ability: ability)

        expect(ability.required_by_assignments_count).to eq(2)
      end
    end

    describe '#is_required_by_assignments?' do
      it 'returns true when ability is required by assignments' do
        create(:assignment_ability, assignment: assignment1, ability: ability)
        expect(ability.is_required_by_assignments?).to be true
      end

      it 'returns false when ability is not required by any assignments' do
        expect(ability.is_required_by_assignments?).to be false
      end
    end

    describe '#highest_milestone_required_by_assignment' do
      it 'returns highest milestone level required by assignment' do
        assignment_ability = create(:assignment_ability, assignment: assignment1, ability: ability, milestone_level: 2)
        assignment_ability.update!(milestone_level: 4)

        expect(ability.highest_milestone_required_by_assignment(assignment1)).to eq(4)
      end

      it 'returns nil when assignment does not require this ability' do
        expect(ability.highest_milestone_required_by_assignment(assignment1)).to be_nil
      end
    end
  end

  describe 'milestone-related methods' do
    let(:ability) { create(:ability, company: company, created_by: person, updated_by: person) }

    describe '#milestone_description' do
      it 'returns description for specific milestone level' do
        ability.milestone_3_description = 'Expert level with ability to handle complex situations'
        expect(ability.milestone_description(3)).to eq('Expert level with ability to handle complex situations')
      end

      it 'returns nil for milestone level without description' do
        expect(ability.milestone_description(4)).to be_nil
      end

      it 'returns nil for invalid milestone level' do
        expect(ability.milestone_description(0)).to be_nil
        expect(ability.milestone_description(6)).to be_nil
      end
    end

    describe '#defined_milestones' do
      it 'returns array of milestone levels that have descriptions' do
        ability.milestone_1_description = 'Basic understanding'
        ability.milestone_3_description = 'Expert level'
        ability.milestone_5_description = 'Master level'

        expect(ability.defined_milestones).to eq([1, 3, 5])
      end

      it 'returns empty array when no milestones defined' do
        expect(ability.defined_milestones).to eq([])
      end
    end

    describe '#has_milestone_definition?' do
      it 'returns true for milestone level with description' do
        ability.milestone_2_description = 'Intermediate level'
        expect(ability.has_milestone_definition?(2)).to be true
      end

      it 'returns false for milestone level without description' do
        expect(ability.has_milestone_definition?(4)).to be false
      end
    end

    describe '#milestone_display' do
      it 'returns formatted milestone with description' do
        ability.milestone_3_description = 'Expert level with ability to handle complex situations'
        expect(ability.milestone_display(3)).to eq('Milestone 3: Expert level with ability to handle complex situations')
      end

      it 'returns just milestone level when no description' do
        expect(ability.milestone_display(3)).to eq('Milestone 3')
      end
    end
  end

  describe '.default_milestone_description' do
    it 'returns template for levels 1 through 5' do
      (1..5).each do |level|
        text = Ability.default_milestone_description(level)
        expect(text).to be_present
        expect(text).to include('I have observed this person')
        expect(text).to include('this ability')
      end
    end

    it 'returns nil for invalid level' do
      expect(Ability.default_milestone_description(0)).to be_nil
      expect(Ability.default_milestone_description(6)).to be_nil
    end

    it 'returns different content per level' do
      one = Ability.default_milestone_description(1)
      five = Ability.default_milestone_description(5)
      expect(one).not_to eq(five)
      expect(one).to include('small amount of guidance')
      expect(five).to include('community/industry')
    end
  end

  describe '#to_param' do
    let(:created_by) { create(:person) }
    let(:updated_by) { create(:person) }
    let(:ability) { create(:ability, company: company, name: 'Ruby Programming', created_by: created_by, updated_by: updated_by) }

    it 'returns id-name-parameterized format based on name' do
      expect(ability.to_param).to eq("#{ability.id}-ruby-programming")
    end

    it 'handles special characters in name' do
      ability = create(:ability, company: company, name: 'C++ & Python!', created_by: created_by, updated_by: updated_by)
      expect(ability.to_param).to eq("#{ability.id}-c-python")
    end
  end

  describe '.find_by_param' do
    let(:created_by) { create(:person) }
    let(:updated_by) { create(:person) }
    let(:ability) { create(:ability, company: company, name: 'Test Ability', created_by: created_by, updated_by: updated_by) }

    it 'finds by numeric id' do
      expect(Ability.find_by_param(ability.id.to_s)).to eq(ability)
    end

    it 'finds by id-name-parameterized format' do
      param = "#{ability.id}-test-ability"
      expect(Ability.find_by_param(param)).to eq(ability)
    end

    it 'extracts id from id-name format' do
      param = "#{ability.id}-some-other-name"
      expect(Ability.find_by_param(param)).to eq(ability)
    end

    it 'raises error for invalid id' do
      expect {
        Ability.find_by_param('999999')
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
