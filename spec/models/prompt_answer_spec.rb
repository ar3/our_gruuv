require 'rails_helper'

RSpec.describe PromptAnswer, type: :model do
  let(:company) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { CompanyTeammate.create!(person: person, organization: company) }
  let(:template) { create(:prompt_template, company: company) }
  let(:prompt) { create(:prompt, company_teammate: teammate, prompt_template: template) }
  let(:question) { create(:prompt_question, prompt_template: template) }

  describe 'associations' do
    it { should belong_to(:prompt) }
    it { should belong_to(:prompt_question) }
    it { should belong_to(:updated_by_company_teammate).optional }
  end

  describe 'validations' do
    it { should validate_presence_of(:prompt) }
    it { should validate_presence_of(:prompt_question) }
    
    it 'validates uniqueness of prompt_question_id scoped to prompt_id' do
      answer1 = create(:prompt_answer, prompt: prompt, prompt_question: question)
      answer2 = build(:prompt_answer, prompt: prompt, prompt_question: question)
      expect(answer2).not_to be_valid
      expect(answer2.errors[:prompt_question_id]).to be_present
    end
  end

  describe 'paper trail' do
    it 'has paper trail enabled' do
      answer = create(:prompt_answer, prompt: prompt, prompt_question: question)
      expect(answer).to respond_to(:versions)
    end
  end

  describe 'updated_by_company_teammate tracking' do
    let(:updater_person) { create(:person) }
    let(:updater_teammate) { CompanyTeammate.create!(person: updater_person, organization: company) }
    let(:answer) { create(:prompt_answer, prompt: prompt, prompt_question: question, text: 'Original text') }

    it 'allows setting updated_by_company_teammate' do
      answer.updated_by_company_teammate = updater_teammate
      answer.save!
      expect(answer.reload.updated_by_company_teammate).to eq(updater_teammate)
    end

    it 'allows updated_by_company_teammate to be nil' do
      answer.updated_by_company_teammate = nil
      expect(answer).to be_valid
      answer.save!
      expect(answer.reload.updated_by_company_teammate).to be_nil
    end
  end
end

