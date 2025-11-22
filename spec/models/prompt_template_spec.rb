require 'rails_helper'

RSpec.describe PromptTemplate, type: :model do
  let(:company) { create(:organization, :company) }
  let(:person) { create(:person) }

  describe 'associations' do
    it { should belong_to(:company) }
    it { should have_many(:prompt_questions).dependent(:destroy) }
    # prompts association will be tested in Phase 3 when Prompt model is created
  end

  describe 'validations' do
    it { should validate_presence_of(:title) }
    it { should validate_presence_of(:company) }
  end

  describe 'scopes' do
    let!(:available_template) { create(:prompt_template, company: company, available_at: Date.current) }
    let!(:future_template) { create(:prompt_template, company: company, available_at: 1.week.from_now) }
    let!(:unavailable_template) { create(:prompt_template, company: company, available_at: nil) }
    let!(:primary_template) { create(:prompt_template, company: company, is_primary: true) }
    let!(:secondary_template) { create(:prompt_template, company: company, is_secondary: true) }
    let!(:tertiary_template) { create(:prompt_template, company: company, is_tertiary: true) }

    describe '.available' do
      it 'returns templates with available_at set and <= today' do
        expect(described_class.available).to include(available_template)
        expect(described_class.available).not_to include(future_template, unavailable_template)
      end
    end

    describe '.primary' do
      it 'returns templates with is_primary = true' do
        expect(described_class.primary).to include(primary_template)
        expect(described_class.primary).not_to include(secondary_template, tertiary_template)
      end
    end

    describe '.secondary' do
      it 'returns templates with is_secondary = true' do
        expect(described_class.secondary).to include(secondary_template)
        expect(described_class.secondary).not_to include(primary_template, tertiary_template)
      end
    end

    describe '.tertiary' do
      it 'returns templates with is_tertiary = true' do
        expect(described_class.tertiary).to include(tertiary_template)
        expect(described_class.tertiary).not_to include(primary_template, secondary_template)
      end
    end

    describe '.ordered' do
      let(:test_company) { create(:organization, :company) }
      let!(:template_c) { create(:prompt_template, company: test_company, title: 'C Template') }
      let!(:template_a) { create(:prompt_template, company: test_company, title: 'A Template') }
      let!(:template_b) { create(:prompt_template, company: test_company, title: 'B Template') }

      it 'returns templates ordered by title' do
        ordered = described_class.where(company: test_company).ordered.to_a
        expect(ordered.map(&:id)).to eq([template_a.id, template_b.id, template_c.id])
      end
    end
  end

  describe 'validations for unique types per company' do
    let!(:existing_primary) { create(:prompt_template, company: company, is_primary: true) }
    let!(:existing_secondary) { create(:prompt_template, company: company, is_secondary: true) }
    let!(:existing_tertiary) { create(:prompt_template, company: company, is_tertiary: true) }

    describe 'primary template uniqueness' do
      it 'allows only one primary template per company' do
        new_primary = build(:prompt_template, company: company, is_primary: true)
        expect(new_primary).not_to be_valid
        expect(new_primary.errors[:is_primary]).to include('can only have one primary template per company')
      end

      it 'allows updating existing primary template' do
        existing_primary.title = 'Updated Title'
        expect(existing_primary).to be_valid
      end

      it 'allows primary template in different company' do
        other_company = create(:organization, :company)
        other_primary = build(:prompt_template, company: other_company, is_primary: true)
        expect(other_primary).to be_valid
      end
    end

    describe 'secondary template uniqueness' do
      it 'allows only one secondary template per company' do
        new_secondary = build(:prompt_template, company: company, is_secondary: true)
        expect(new_secondary).not_to be_valid
        expect(new_secondary.errors[:is_secondary]).to include('can only have one secondary template per company')
      end

      it 'allows updating existing secondary template' do
        existing_secondary.title = 'Updated Title'
        expect(existing_secondary).to be_valid
      end

      it 'allows secondary template in different company' do
        other_company = create(:organization, :company)
        other_secondary = build(:prompt_template, company: other_company, is_secondary: true)
        expect(other_secondary).to be_valid
      end
    end

    describe 'tertiary template uniqueness' do
      it 'allows only one tertiary template per company' do
        new_tertiary = build(:prompt_template, company: company, is_tertiary: true)
        expect(new_tertiary).not_to be_valid
        expect(new_tertiary.errors[:is_tertiary]).to include('can only have one tertiary template per company')
      end

      it 'allows updating existing tertiary template' do
        existing_tertiary.title = 'Updated Title'
        expect(existing_tertiary).to be_valid
      end

      it 'allows tertiary template in different company' do
        other_company = create(:organization, :company)
        other_tertiary = build(:prompt_template, company: other_company, is_tertiary: true)
        expect(other_tertiary).to be_valid
      end
    end
  end

  describe '#available?' do
    it 'returns true when available_at is present and <= today' do
      template = build(:prompt_template, available_at: Date.current)
      expect(template.available?).to be true
    end

    it 'returns false when available_at is nil' do
      template = build(:prompt_template, available_at: nil)
      expect(template.available?).to be false
    end

    it 'returns false when available_at is in the future' do
      template = build(:prompt_template, available_at: 1.week.from_now)
      expect(template.available?).to be false
    end
  end

  describe 'destruction' do
    it 'allows deletion when no prompts exist' do
      template = create(:prompt_template, company: company)
      expect { template.destroy }.to change { PromptTemplate.count }.by(-1)
    end

    it 'destroys associated prompt_questions' do
      template = create(:prompt_template, company: company)
      question1 = create(:prompt_question, prompt_template: template, position: 1)
      question2 = create(:prompt_question, prompt_template: template, position: 2)

      expect {
        template.destroy
      }.to change { PromptQuestion.count }.by(-2)
      expect(PromptQuestion.where(id: [question1.id, question2.id])).to be_empty
    end

    # Note: Prompt existence check will be tested in Phase 3 when Prompt model is created
  end
end

