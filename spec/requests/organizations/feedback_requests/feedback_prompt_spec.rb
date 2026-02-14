require 'rails_helper'

RSpec.describe 'Organizations::FeedbackRequests::FeedbackPrompt', type: :request do
  let(:company) { create(:organization) }
  let(:requestor_person) { create(:person) }
  let(:requestor_teammate) do
    CompanyTeammate.find_or_create_by!(person: requestor_person, organization: company) do |t|
      t.organization = company
    end
  end
  let(:subject_person) { create(:person) }
  let(:subject_teammate) do
    CompanyTeammate.find_or_create_by!(person: subject_person, organization: company) do |t|
      t.organization = company
    end
  end
  let(:feedback_request) do
    create(:feedback_request,
      company: company,
      requestor_teammate: requestor_teammate,
      subject_of_feedback_teammate: subject_teammate,
      subject_line: 'Test feedback request'
    )
  end
  let(:question1) { build(:feedback_request_question, feedback_request: feedback_request, question_text: '', position: 1).tap { |q| q.save(validate: false) } }
  let(:question2) { build(:feedback_request_question, feedback_request: feedback_request, question_text: '', position: 2).tap { |q| q.save(validate: false) } }

  before do
    requestor_teammate.update!(organization: company) if requestor_teammate.organization != company
    subject_teammate.update!(organization: company) if subject_teammate.organization != company
    sign_in_as_teammate_for_request(requestor_person, company)
    question1
    question2
  end

  describe 'GET /organizations/:organization_id/feedback_requests/:id/feedback_prompt' do
    it 'renders the feedback_prompt page' do
      get feedback_prompt_organization_feedback_request_path(company, feedback_request)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Feedback Questions')
    end

    it 'defaults blank assignment question to sentiment outcomes separated by double newlines' do
      assignment = create(:assignment, company: company)
      create(:assignment_outcome, :sentiment, assignment: assignment, description: 'Team agrees: We ship on time')
      create(:assignment_outcome, :sentiment, assignment: assignment, description: 'Stakeholders agree: Communication is clear')
      build(:feedback_request_question, :with_blank_text, feedback_request: feedback_request, position: 3, rateable: assignment).save(validate: false)

      get feedback_prompt_organization_feedback_request_path(company, feedback_request)

      expect(response).to have_http_status(:success)
      # Default text should appear in the textarea value for the assignment question
      expect(response.body).to include('Team agrees: We ship on time')
      expect(response.body).to include('Stakeholders agree: Communication is clear')
      expect(response.body).to include("Team agrees: We ship on time\n\nStakeholders agree: Communication is clear")
    end

    it 'defaults blank assignment question without sentiment outcomes to experience-of-subject-being-assignment sentence' do
      assignment = create(:assignment, company: company, title: 'Product Lead')
      create(:assignment_outcome, :quantitative, assignment: assignment, description: 'Ship 5 features')
      build(:feedback_request_question, :with_blank_text, feedback_request: feedback_request, position: 3, rateable: assignment).save(validate: false)

      get feedback_prompt_organization_feedback_request_path(company, feedback_request)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('When I think about my recent experience of ')
      expect(response.body).to include(' being a Product Lead...')
    end

    it 'defaults blank ability question to demonstrating sentence' do
      ability = create(:ability, company: company, name: 'Technical Communication')
      build(:feedback_request_question, :with_blank_text, feedback_request: feedback_request, position: 3, rateable: ability).save(validate: false)

      get feedback_prompt_organization_feedback_request_path(company, feedback_request)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('When I think about my recent experience of ')
      expect(response.body).to include(' demonstrating Technical Communication...')
    end

    it 'defaults blank aspiration question to demonstrating sentence' do
      aspiration = create(:aspiration, company: company, name: 'Growing as a leader')
      build(:feedback_request_question, :with_blank_text, feedback_request: feedback_request, position: 3, rateable: aspiration).save(validate: false)

      get feedback_prompt_organization_feedback_request_path(company, feedback_request)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('When I think about my recent experience of ')
      expect(response.body).to include(' demonstrating Growing as a leader...')
    end

    it 'requires authorization' do
      other_person = create(:person)
      sign_in_as_teammate_for_request(other_person, company)

      get feedback_prompt_organization_feedback_request_path(company, feedback_request)
      expect(response).to have_http_status(:redirect)
    end
  end

  describe 'PATCH /organizations/:organization_id/feedback_requests/:id/update_questions' do
    it 'updates question text' do
      patch update_questions_organization_feedback_request_path(company, feedback_request), params: {
        questions: {
          question1.id.to_s => { question_text: 'Question 1 text' },
          question2.id.to_s => { question_text: 'Question 2 text' }
        }
      }
      expect(response).to redirect_to(select_respondents_organization_feedback_request_path(company, feedback_request))
      question1.reload
      question2.reload
      expect(question1.question_text).to eq('Question 1 text')
      expect(question2.question_text).to eq('Question 2 text')
    end

    it 'redirects with error if any question is blank' do
      patch update_questions_organization_feedback_request_path(company, feedback_request), params: {
        questions: {
          question1.id.to_s => { question_text: 'Question 1 text' },
          question2.id.to_s => { question_text: '' }
        }
      }
      expect(response).to redirect_to(feedback_prompt_organization_feedback_request_path(company, feedback_request))
      expect(flash[:alert]).to include('All questions must have text')
    end
  end
end
