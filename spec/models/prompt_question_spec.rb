require 'rails_helper'

RSpec.describe PromptQuestion, type: :model do
  let(:company) { create(:organization, :company) }
  let(:template) { create(:prompt_template, company: company) }

  describe 'associations' do
    it { should belong_to(:prompt_template) }
    # prompt_answers association will be tested in Phase 3 when PromptAnswer model is created
  end

  describe 'validations' do
    it { should validate_presence_of(:label) }
    it { should validate_presence_of(:position) }
    
    it 'validates uniqueness of position scoped to prompt_template_id' do
      question1 = create(:prompt_question, prompt_template: template, position: 1)
      question2 = build(:prompt_question, prompt_template: template, position: 1)
      expect(question2).not_to be_valid
      expect(question2.errors[:position]).to be_present
    end
  end

  describe 'paper trail' do
    it 'has paper trail enabled' do
      question = create(:prompt_question, prompt_template: template)
      expect(question).to respond_to(:versions)
    end
  end

  describe 'position auto-assignment' do
    it 'automatically sets position on create if not provided' do
      question1 = create(:prompt_question, prompt_template: template, position: nil)
      expect(question1.position).to eq(1)

      question2 = create(:prompt_question, prompt_template: template, position: nil)
      expect(question2.position).to eq(2)
    end

    it 'respects manually set position' do
      question = create(:prompt_question, prompt_template: template, position: 5)
      expect(question.position).to eq(5)
    end
  end

  describe 'scopes' do
    let!(:question1) { create(:prompt_question, prompt_template: template, position: 2) }
    let!(:question2) { create(:prompt_question, prompt_template: template, position: 1) }
    let!(:question3) { create(:prompt_question, prompt_template: template, position: 3) }

    describe '.ordered' do
      it 'returns questions ordered by position' do
        expect(template.prompt_questions.ordered).to eq([question2, question1, question3])
      end
    end
  end
end

