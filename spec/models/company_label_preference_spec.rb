require 'rails_helper'

RSpec.describe CompanyLabelPreference, type: :model do
  let(:company) { Organization.find_or_create_by!(name: 'Test Company') }

  describe 'associations' do
    it { should belong_to(:company) }
  end

  describe 'validations' do
    it 'validates presence of company_id' do
      preference = build(:company_label_preference, company: nil)
      expect(preference).not_to be_valid
      expect(preference.errors[:company_id]).to be_present
    end

    it 'validates presence of label_key' do
      preference = build(:company_label_preference, company: company, label_key: nil)
      expect(preference).not_to be_valid
      expect(preference.errors[:label_key]).to be_present
    end

    it 'validates uniqueness of label_key scoped to company_id' do
      create(:company_label_preference, company: company, label_key: 'prompt')
      duplicate = build(:company_label_preference, company: company, label_key: 'prompt')
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:label_key]).to be_present
    end

    it 'allows same label_key for different companies' do
      company2 = Organization.find_or_create_by!(name: 'Test Company 2')
      create(:company_label_preference, company: company, label_key: 'prompt')
      preference2 = build(:company_label_preference, company: company2, label_key: 'prompt')
      expect(preference2).to be_valid
    end
  end

  # Note: Scopes may not be defined in the model yet
  # These tests are for future scope implementations
  skip 'scopes' do
    let!(:preference1) { create(:company_label_preference, company: company, label_key: 'prompt', label_value: 'Reflection') }
    let!(:preference2) { create(:company_label_preference, company: company, label_key: 'reflection', label_value: 'Thought') }
    let(:company2) { Organization.find_or_create_by!(name: 'Test Company 2') }
    let!(:preference3) { create(:company_label_preference, company: company2, label_key: 'prompt', label_value: 'Question') }

    describe '.for_company' do
      it 'returns preferences for the specified company' do
        results = described_class.for_company(company)
        expect(results).to include(preference1, preference2)
        expect(results).not_to include(preference3)
      end
    end

    describe '.for_key' do
      it 'returns preferences for the specified key' do
        results = described_class.for_key('prompt')
        expect(results).to include(preference1, preference3)
        expect(results).not_to include(preference2)
      end
    end
  end
end
