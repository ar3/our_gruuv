require 'rails_helper'

RSpec.describe FeedbackRequestQuestion, type: :model do
  describe 'validations' do
    it 'allows blank question_text for placeholder questions (filled in feedback_prompt step)' do
      feedback_request = create(:feedback_request)
      question = build(:feedback_request_question, :with_blank_text, feedback_request: feedback_request, position: 1)
      expect(question).to be_valid
    end

    it 'allows question_text to be set' do
      feedback_request = create(:feedback_request)
      question = build(:feedback_request_question, feedback_request: feedback_request, position: 1, question_text: 'What did you observe?')
      expect(question).to be_valid
    end
  end

  describe '#prompt_default_text' do
    it 'returns question_text when present' do
      feedback_request = create(:feedback_request)
      question = create(:feedback_request_question, feedback_request: feedback_request, position: 1, question_text: 'Custom question?')
      expect(question.prompt_default_text).to eq('Custom question?')
    end

    it 'returns empty string when question_text blank and rateable is not an Assignment' do
      feedback_request = create(:feedback_request)
      question = create(:feedback_request_question, :with_blank_text, feedback_request: feedback_request, position: 1, rateable_type: nil, rateable_id: nil)
      expect(question.prompt_default_text).to eq('')
    end

    it 'returns experience-of-subject-being-assignment sentence when question blank and Assignment has no sentiment outcomes' do
      feedback_request = create(:feedback_request)
      assignment = create(:assignment, company: feedback_request.company, title: 'Product Lead')
      create(:assignment_outcome, :quantitative, assignment: assignment, description: 'Quantitative only')
      question = create(:feedback_request_question, :with_blank_text, feedback_request: feedback_request, position: 1, rateable: assignment)
      expect(question.prompt_default_text).to start_with('When I think about my recent experience of ')
      expect(question.prompt_default_text).to include(' being a Product Lead...')
      expect(question.prompt_default_text).to end_with('...')
    end

    it 'uses subject casual name in fallback when Assignment has no sentiment outcomes' do
      person = create(:person, first_name: 'Jordan', last_name: 'Smith', preferred_name: 'Jo')
      feedback_request = create(:feedback_request)
      teammate = create(:company_teammate, person: person, organization: feedback_request.company)
      feedback_request.update!(subject_of_feedback_teammate: teammate)
      assignment = create(:assignment, company: feedback_request.company, title: 'Engineering Manager')
      question = create(:feedback_request_question, :with_blank_text, feedback_request: feedback_request, position: 1, rateable: assignment)
      expect(question.prompt_default_text).to eq('When I think about my recent experience of Jo being a Engineering Manager...')
    end

    it 'returns sentiment outcome descriptions joined by double newlines when question blank and Assignment has sentiment outcomes' do
      feedback_request = create(:feedback_request)
      assignment = create(:assignment, company: feedback_request.company)
      create(:assignment_outcome, :sentiment, assignment: assignment, description: 'Team agrees: We ship on time')
      create(:assignment_outcome, :sentiment, assignment: assignment, description: 'Stakeholders agree: Communication is clear')
      question = create(:feedback_request_question, :with_blank_text, feedback_request: feedback_request, position: 1, rateable: assignment)
      expect(question.prompt_default_text).to eq("Team agrees: We ship on time\n\nStakeholders agree: Communication is clear")
    end

    it 'returns only sentiment outcomes when Assignment has mixed outcome types' do
      feedback_request = create(:feedback_request)
      assignment = create(:assignment, company: feedback_request.company)
      create(:assignment_outcome, :quantitative, assignment: assignment, description: 'Reduce latency to 100ms')
      create(:assignment_outcome, :sentiment, assignment: assignment, description: 'Squad agrees: We learn continuously')
      question = create(:feedback_request_question, :with_blank_text, feedback_request: feedback_request, position: 1, rateable: assignment)
      expect(question.prompt_default_text).to eq('Squad agrees: We learn continuously')
    end

    it 'returns demonstrating sentence when question blank and rateable is Ability' do
      feedback_request = create(:feedback_request)
      ability = create(:ability, company: feedback_request.company, name: 'Technical Communication')
      question = create(:feedback_request_question, :with_blank_text, feedback_request: feedback_request, position: 1, rateable: ability)
      expect(question.prompt_default_text).to start_with('When I think about my recent experience of ')
      expect(question.prompt_default_text).to include(' demonstrating Technical Communication...')
      expect(question.prompt_default_text).to end_with('...')
    end

    it 'returns demonstrating sentence when question blank and rateable is Aspiration' do
      feedback_request = create(:feedback_request)
      aspiration = create(:aspiration, company: feedback_request.company, name: 'Growing as a leader')
      question = create(:feedback_request_question, :with_blank_text, feedback_request: feedback_request, position: 1, rateable: aspiration)
      expect(question.prompt_default_text).to start_with('When I think about my recent experience of ')
      expect(question.prompt_default_text).to include(' demonstrating Growing as a leader...')
      expect(question.prompt_default_text).to end_with('...')
    end

    it 'uses subject casual name in demonstrating fallback for Ability' do
      person = create(:person, first_name: 'Sam', last_name: 'Jones', preferred_name: 'Sammy')
      feedback_request = create(:feedback_request)
      teammate = create(:company_teammate, person: person, organization: feedback_request.company)
      feedback_request.update!(subject_of_feedback_teammate: teammate)
      ability = create(:ability, company: feedback_request.company, name: 'Collaboration')
      question = create(:feedback_request_question, :with_blank_text, feedback_request: feedback_request, position: 1, rateable: ability)
      expect(question.prompt_default_text).to eq('When I think about my recent experience of Sammy demonstrating Collaboration...')
    end
  end
end
