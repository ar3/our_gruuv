require 'rails_helper'

RSpec.describe Assignment, type: :model do
  let(:company) { create(:organization, type: 'Company') }
  let(:assignment) { create(:assignment, company: company) }

  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(assignment).to be_valid
    end

    it 'requires title' do
      assignment.title = nil
      expect(assignment).not_to be_valid
    end

    it 'requires tagline' do
      assignment.tagline = nil
      expect(assignment).not_to be_valid
    end

    it 'requires company' do
      assignment.company = nil
      expect(assignment).not_to be_valid
    end
  end

  describe 'associations' do
    it 'belongs to a company' do
      expect(assignment.company).to eq(company)
    end

    it 'has many assignment outcomes' do
      expect(assignment.assignment_outcomes).to be_empty
    end

    it 'has one published external reference' do
      expect(assignment.published_external_reference).to be_nil
    end

    it 'has one draft external reference' do
      expect(assignment.draft_external_reference).to be_nil
    end
  end

  describe 'instance methods' do
    it 'returns display name' do
      expect(assignment.display_name).to eq(assignment.title)
    end

    it 'returns company name' do
      expect(assignment.company_name).to eq(company.display_name)
    end
  end

  describe 'external references' do
    let(:assignment_with_urls) { create(:assignment, :with_source_urls, company: company) }

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
end
