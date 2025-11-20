require 'rails_helper'

RSpec.describe Assignment, type: :model do
  let(:organization) { create(:organization) }
  let(:assignment) { create(:assignment, company: organization) }

  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(assignment).to be_valid
    end

    it 'requires a title' do
      assignment.title = nil
      expect(assignment).not_to be_valid
      expect(assignment.errors[:title]).to include("can't be blank")
    end

    it 'requires a tagline' do
      assignment.tagline = nil
      expect(assignment).not_to be_valid
      expect(assignment.errors[:tagline]).to include("can't be blank")
    end

    it 'requires a company' do
      assignment.company = nil
      expect(assignment).not_to be_valid
      expect(assignment.errors[:company]).to include("must exist")
    end

    it 'enforces unique titles within the same organization' do
      create(:assignment, title: 'Software Engineer', company: organization)
      duplicate_assignment = build(:assignment, title: 'Software Engineer', company: organization)
      
      expect(duplicate_assignment).not_to be_valid
      expect(duplicate_assignment.errors[:title]).to include('has already been taken')
    end

    it 'allows duplicate titles across different organizations' do
      other_organization = create(:organization)
      create(:assignment, title: 'Software Engineer', company: organization)
      duplicate_assignment = build(:assignment, title: 'Software Engineer', company: other_organization)
      
      expect(duplicate_assignment).to be_valid
    end
  end

  describe 'associations' do
    it 'belongs to a company' do
      expect(assignment.company).to eq(organization)
    end

    it 'has many assignment outcomes' do
      expect(assignment.assignment_outcomes).to be_empty
    end

    it 'has many assignment abilities' do
      expect(assignment.assignment_abilities).to be_empty
    end

    it 'has many abilities through assignment abilities' do
      expect(assignment.abilities).to be_empty
    end

    it 'has one published external reference' do
      expect(assignment.published_external_reference).to be_nil
    end

    it 'has one draft external reference' do
      expect(assignment.draft_external_reference).to be_nil
    end
  end

  describe 'instance methods' do
    it 'returns display name with version' do
      expect(assignment.display_name).to eq("#{assignment.title} v#{assignment.semantic_version}")
    end

    it 'returns company name' do
      expect(assignment.company_name).to eq(organization.display_name)
    end
  end

  describe 'ability-related methods' do
    let(:ability1) { create(:ability, organization: organization) }
    let(:ability2) { create(:ability, organization: organization) }

    describe '#required_abilities' do
      it 'returns abilities ordered by milestone level' do
        create(:assignment_ability, assignment: assignment, ability: ability2, milestone_level: 3)
        create(:assignment_ability, assignment: assignment, ability: ability1, milestone_level: 1)

        result = assignment.required_abilities
        expect(result.map(&:ability)).to eq([ability1, ability2])
      end
    end

    describe '#required_abilities_count' do
      it 'returns count of required abilities' do
        create(:assignment_ability, assignment: assignment, ability: ability1)
        create(:assignment_ability, assignment: assignment, ability: ability2)

        expect(assignment.required_abilities_count).to eq(2)
      end
    end

    describe '#has_ability_requirements?' do
      it 'returns true when assignment has ability requirements' do
        create(:assignment_ability, assignment: assignment, ability: ability1)
        expect(assignment.has_ability_requirements?).to be true
      end

      it 'returns false when assignment has no ability requirements' do
        expect(assignment.has_ability_requirements?).to be false
      end
    end

    describe '#highest_milestone_for_ability' do
      it 'returns highest milestone level for ability' do
        # Update the existing assignment_ability to have milestone level 4
        assignment_ability = create(:assignment_ability, assignment: assignment, ability: ability1, milestone_level: 2)
        assignment_ability.update!(milestone_level: 4)

        expect(assignment.highest_milestone_for_ability(ability1)).to eq(4)
      end

      it 'returns nil when ability not required' do
        expect(assignment.highest_milestone_for_ability(ability1)).to be_nil
      end
    end

    describe '#add_ability_requirement' do
      it 'adds ability requirement' do
        expect {
          assignment.add_ability_requirement(ability1, 3)
        }.to change(assignment.assignment_abilities, :count).by(1)

        assignment_ability = assignment.assignment_abilities.last
        expect(assignment_ability.ability).to eq(ability1)
        expect(assignment_ability.milestone_level).to eq(3)
      end
    end

    describe '#remove_ability_requirement' do
      it 'removes ability requirement' do
        create(:assignment_ability, assignment: assignment, ability: ability1)

        expect {
          assignment.remove_ability_requirement(ability1)
        }.to change(assignment.assignment_abilities, :count).by(-1)
      end
    end
  end

  describe 'external references' do
    let(:assignment_with_urls) { create(:assignment, :with_source_urls, company: organization) }

    it 'can have published external reference' do
      expect(assignment_with_urls.published_external_reference).to be_present
      expect(assignment_with_urls.published_external_reference.reference_type).to eq('published')
    end

    it 'can have draft external reference' do
      expect(assignment_with_urls.draft_external_reference).to be_present
      expect(assignment_with_urls.draft_external_reference.reference_type).to eq('draft')
    end

    it 'returns published URL' do
      expect(assignment_with_urls.published_url).to eq("https://docs.google.com/document/d/published-example")
    end

    it 'returns draft URL' do
      expect(assignment_with_urls.draft_url).to eq("https://docs.google.com/document/d/draft-example")
    end

    it 'returns nil for missing references' do
      expect(assignment.published_external_reference).to be_nil
      expect(assignment.draft_external_reference).to be_nil
      expect(assignment.published_url).to be_nil
      expect(assignment.draft_url).to be_nil
    end
  end

  describe '#create_outcomes_from_textarea' do
    it 'creates outcomes from textarea input' do
      text = "Increase customer satisfaction by 20%\nReduce response time to under 2 hours\nTeam agrees: We communicate clearly"
      
      assignment.create_outcomes_from_textarea(text)
      
      expect(assignment.assignment_outcomes.count).to eq(3)
      expect(assignment.assignment_outcomes.pluck(:description)).to include(
        'Increase customer satisfaction by 20%',
        'Reduce response time to under 2 hours',
        'Team agrees: We communicate clearly'
      )
    end

    it 'sets quantitative type by default' do
      text = "Increase customer satisfaction by 20%"
      assignment.create_outcomes_from_textarea(text)
      
      outcome = assignment.assignment_outcomes.first
      expect(outcome.outcome_type).to eq('quantitative')
    end

    it 'sets sentiment type when contains agree:' do
      text = "Team agrees: We communicate clearly"
      assignment.create_outcomes_from_textarea(text)
      
      outcome = assignment.assignment_outcomes.first
      expect(outcome.outcome_type).to eq('sentiment')
    end

    it 'sets sentiment type when contains agrees:' do
      text = "Team agrees: We work efficiently"
      assignment.create_outcomes_from_textarea(text)
      
      outcome = assignment.assignment_outcomes.first
      expect(outcome.outcome_type).to eq('sentiment')
    end

    it 'handles case insensitive detection' do
      text = "Team AGREES: We communicate clearly"
      assignment.create_outcomes_from_textarea(text)
      
      outcome = assignment.assignment_outcomes.first
      expect(outcome.outcome_type).to eq('sentiment')
    end

    it 'ignores empty lines and whitespace' do
      text = "  \nIncrease customer satisfaction\n  \n\nReduce response time\n"
      assignment.create_outcomes_from_textarea(text)
      
      expect(assignment.assignment_outcomes.count).to eq(2)
      expect(assignment.assignment_outcomes.pluck(:description)).to include(
        'Increase customer satisfaction',
        'Reduce response time'
      )
    end

    it 'does nothing with blank text' do
      assignment.create_outcomes_from_textarea("")
      assignment.create_outcomes_from_textarea(nil)
      
      expect(assignment.assignment_outcomes.count).to eq(0)
    end
  end

  describe '#to_param' do
    it 'returns id-name-parameterized format based on title' do
      assignment = create(:assignment, company: organization, title: 'Frontend Development')
      expect(assignment.to_param).to eq("#{assignment.id}-frontend-development")
    end

    it 'handles special characters in title' do
      assignment = create(:assignment, company: organization, title: 'Backend & API Development!')
      expect(assignment.to_param).to eq("#{assignment.id}-backend-api-development")
    end
  end

  describe '.find_by_param' do
    let(:assignment) { create(:assignment, company: organization, title: 'Test Assignment') }

    it 'finds by numeric id' do
      expect(Assignment.find_by_param(assignment.id.to_s)).to eq(assignment)
    end

    it 'finds by id-name-parameterized format' do
      param = "#{assignment.id}-test-assignment"
      expect(Assignment.find_by_param(param)).to eq(assignment)
    end

    it 'extracts id from id-name format' do
      param = "#{assignment.id}-some-other-name"
      expect(Assignment.find_by_param(param)).to eq(assignment)
    end

    it 'raises error for invalid id' do
      expect {
        Assignment.find_by_param('999999')
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
