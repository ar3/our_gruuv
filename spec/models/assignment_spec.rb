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

    describe 'URL validations' do
      it 'accepts valid URLs' do
        assignment.published_source_url = 'https://docs.google.com/document/d/example'
        assignment.draft_source_url = 'https://docs.google.com/document/d/draft'
        expect(assignment).to be_valid
      end

      it 'rejects invalid URLs' do
        assignment.published_source_url = 'not-a-url'
        expect(assignment).not_to be_valid
        expect(assignment.errors[:published_source_url]).to include('must be a valid URL')
      end

      it 'allows blank URLs' do
        assignment.published_source_url = ''
        assignment.draft_source_url = nil
        expect(assignment).to be_valid
      end
    end
  end

  describe 'associations' do
    it 'belongs to a company' do
      expect(assignment.company).to eq(company)
    end

    it 'has many assignment outcomes' do
      expect(assignment.assignment_outcomes).to be_empty
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

  describe 'source URLs' do
    let(:assignment_with_urls) { create(:assignment, :with_source_urls, company: company) }

    it 'can have published source URL' do
      expect(assignment_with_urls.published_source_url).to be_present
    end

    it 'can have draft source URL' do
      expect(assignment_with_urls.draft_source_url).to be_present
    end
  end
end
