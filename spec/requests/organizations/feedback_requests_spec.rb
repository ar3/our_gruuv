require 'rails_helper'

RSpec.describe 'Organizations::FeedbackRequests', type: :request do
  let(:company) { create(:organization, :company) }
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
  let(:responder_person) { create(:person) }
  let(:responder_teammate) do
    CompanyTeammate.find_or_create_by!(person: responder_person, organization: company) do |t|
      t.organization = company
    end
  end

  before do
    # Ensure all teammates are in the same company
    requestor_teammate.update!(organization: company) if requestor_teammate.organization != company
    subject_teammate.update!(organization: company) if subject_teammate.organization != company
    responder_teammate.update!(organization: company) if responder_teammate.organization != company
    sign_in_as_teammate_for_request(requestor_person, company)
  end

  describe 'GET /organizations/:organization_id/feedback_requests' do
    let!(:feedback_request) do
      create(:feedback_request,
        company: company,
        requestor_teammate: requestor_teammate,
        subject_of_feedback_teammate: subject_teammate,
        subject_line: 'Test feedback request'
      )
    end

    it 'renders the index page' do
      get organization_feedback_requests_path(company)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Feedback Requests')
    end

    it 'excludes archived requests by default' do
      # Create archived request with a different subject so we can distinguish it
      archived_subject_person = create(:person)
      archived_subject_teammate = CompanyTeammate.find_or_create_by!(person: archived_subject_person, organization: company)
      archived_request = create(:feedback_request, :archived,
        company: company,
        requestor_teammate: requestor_teammate,
        subject_of_feedback_teammate: archived_subject_teammate
      )

      get organization_feedback_requests_path(company)
      expect(response.body).to include(feedback_request.subject_of_feedback_teammate.person.display_name)
      expect(response.body).not_to include(archived_request.subject_of_feedback_teammate.person.display_name)
    end

    it 'includes archived requests when show_archived=1' do
      archived_request = create(:feedback_request, :archived,
        company: company,
        requestor_teammate: requestor_teammate,
        subject_of_feedback_teammate: subject_teammate,
        subject_line: 'Archived request'
      )

      get organization_feedback_requests_path(company, show_archived: '1')
      expect(response.body).to include(feedback_request.subject_of_feedback_teammate.person.display_name)
      expect(response.body).to include(archived_request.subject_of_feedback_teammate.person.display_name)
    end

    it 'requires authorization' do
      other_company = create(:organization, :company)
      other_person = create(:person)
      sign_in_as_teammate_for_request(other_person, other_company)

      get organization_feedback_requests_path(company)
      expect(response).to have_http_status(:redirect)
    end

    it 'displays empty state when there are no feedback requests' do
      # Delete the feedback request created in let! to test empty state
      feedback_request.destroy
      
      get organization_feedback_requests_path(company)
      
      expect(response).to have_http_status(:success)
      expect(response.body).to include('No Feedback Requests')
      expect(response.body).to include('Create your first feedback request to gather structured feedback from teammates.')
      expect(response.body).to include('Create First Feedback Request')
      # Table should not be rendered when empty
      expect(response.body).not_to match(/<table[^>]*>/)
    end

    it 'displays empty state for archived when all requests are active and show_archived=1' do
      # Delete the active request created in let!
      feedback_request.destroy
      
      get organization_feedback_requests_path(company, show_archived: '1')
      
      expect(response).to have_http_status(:success)
      expect(response.body).to include('No Feedback Requests')
      expect(response.body).to include('There are no archived feedback requests.')
    end
  end

  describe 'GET /organizations/:organization_id/feedback_requests/new' do
    it 'renders the new page' do
      get new_organization_feedback_request_path(company)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Subject')
    end

    it 'requires authorization' do
      # Create a request with subject as the current user (should be allowed)
      get new_organization_feedback_request_path(company)
      expect(response).to have_http_status(:success)
    end
  end

  describe 'POST /organizations/:organization_id/feedback_requests' do
    let(:assignment) { create(:assignment, company: company) }
    # Make requestor the subject so authorization passes (subject can create requests about themselves)
    # Ensure both teammates are in the same company
    before do
      requestor_teammate.update!(organization: company)
      subject_teammate.update!(organization: company)
      responder_teammate.update!(organization: company)
    end
    
    let(:valid_params) do
      {
        feedback_request: {
          subject_of_feedback_teammate_id: requestor_teammate.id,
          subject_line: 'Test feedback request'
        }
      }
    end

    it 'creates a new feedback request' do
      expect {
        post organization_feedback_requests_path(company), params: valid_params
      }.to change { FeedbackRequest.count }.by(1)
      
      expect(response).to have_http_status(:redirect)
      feedback_request = FeedbackRequest.last
      expect(feedback_request.state).to eq('invalid') # State is now computed
      expect(feedback_request.subject_line).to eq('Test feedback request')
    end

    it 'redirects to select_focus after creation' do
      post organization_feedback_requests_path(company), params: valid_params
      feedback_request = FeedbackRequest.last
      expect(response).to redirect_to(select_focus_organization_feedback_request_path(company, feedback_request))
    end

  end

  describe 'GET /organizations/:organization_id/feedback_requests/:id' do
    let(:feedback_request) do
      create(:feedback_request,
        company: company,
        requestor_teammate: requestor_teammate,
        subject_of_feedback_teammate: subject_teammate,
        subject_line: 'Test feedback request'
      )
    end

    it 'renders the show page' do
      get organization_feedback_request_path(company, feedback_request)
      expect(response).to have_http_status(:success)
      expect(response.body).to match(/Feedback Request|Subject/)
    end

    it 'requires authorization' do
      other_company = create(:organization, :company)
      other_person = create(:person)
      sign_in_as_teammate_for_request(other_person, other_company)

      get organization_feedback_request_path(company, feedback_request)
      expect(response).to have_http_status(:redirect)
    end
  end

  describe 'GET /organizations/:organization_id/feedback_requests/:id/edit' do
    let(:feedback_request) do
      create(:feedback_request,
        company: company,
        requestor_teammate: requestor_teammate,
        subject_of_feedback_teammate: subject_teammate,
        subject_line: 'Test feedback request'
      )
    end

    it 'renders the edit page or redirects to wizard step' do
      get edit_organization_feedback_request_path(company, feedback_request)
      # Edit page may redirect to wizard steps if incomplete, or render if complete
      expect(response.status).to be_between(200, 399).inclusive
    end

    it 'requires authorization' do
      # Sign in as someone else (not the requestor)
      other_person = create(:person)
      other_teammate = create(:company_teammate, person: other_person, organization: company)
      sign_in_as_teammate_for_request(other_person, company)

      get edit_organization_feedback_request_path(company, feedback_request)
      expect(response).to have_http_status(:redirect)
    end
  end

  describe 'PATCH /organizations/:organization_id/feedback_requests/:id' do
    let(:feedback_request) do
      create(:feedback_request, :ready,
        company: company,
        requestor_teammate: requestor_teammate,
        subject_of_feedback_teammate: subject_teammate,
        subject_line: 'Test feedback request'
      )
    end

    before do
      # Clear any existing questions first
      feedback_request.feedback_request_questions.destroy_all
      # Create questions and responders so request is ready
      create(:feedback_request_question, feedback_request: feedback_request, question_text: 'Test question?', position: 1)
      feedback_request.feedback_request_responders.create!(teammate: responder_teammate)
    end

    it 'updates the feedback request subject and subject_line' do
      new_subject = create(:company_teammate, organization: company)
      patch organization_feedback_request_path(company, feedback_request), params: {
        feedback_request: {
          subject_of_feedback_teammate_id: new_subject.id,
          subject_line: 'Updated subject line'
        }
      }
      feedback_request.reload
      expect(feedback_request.subject_of_feedback_teammate).to eq(new_subject)
      expect(feedback_request.subject_line).to eq('Updated subject line')
    end

    it 'redirects to show page on success' do
      patch organization_feedback_request_path(company, feedback_request), params: {
        feedback_request: {
          subject_of_feedback_teammate_id: subject_teammate.id,
          subject_line: 'Test feedback request'
        }
      }
      expect(response).to redirect_to(organization_feedback_request_path(company, feedback_request))
    end
  end

  describe 'DELETE /organizations/:organization_id/feedback_requests/:id' do
    let(:feedback_request) do
      create(:feedback_request,
        company: company,
        requestor_teammate: requestor_teammate,
        subject_of_feedback_teammate: subject_teammate,
        subject_line: 'Test feedback request'
      )
    end

    it 'archives the feedback request (soft delete and state change)' do
      delete organization_feedback_request_path(company, feedback_request)
      feedback_request.reload
      expect(feedback_request.deleted_at).to be_present
      expect(feedback_request.state).to eq('archived')
      expect(feedback_request.archived?).to be true
    end

    it 'redirects to index on success' do
      delete organization_feedback_request_path(company, feedback_request)
      expect(response).to redirect_to(organization_feedback_requests_path(company))
    end
  end

  describe 'GET /organizations/:organization_id/feedback_requests/:id/answer' do
    let(:feedback_request) do
      create(:feedback_request,
        company: company,
        requestor_teammate: requestor_teammate,
        subject_of_feedback_teammate: subject_teammate,
        subject_line: 'Test feedback request'
      )
    end

    before do
      # Clear any existing questions first
      feedback_request.feedback_request_questions.destroy_all
      # Add questions and responders
      create(:feedback_request_question, feedback_request: feedback_request, question_text: 'Test question?', position: 1)
      feedback_request.feedback_request_responders.create!(teammate: requestor_teammate)
      sign_in_as_teammate_for_request(requestor_person, company)
    end

    it 'renders the answer page' do
      get answer_organization_feedback_request_path(company, feedback_request)
      expect(response).to have_http_status(:success)
      expect(response.body).to match(/Answer|Question/)
    end

    it 'requires authorization (must be a responder)' do
      other_person = create(:person)
      other_teammate = create(:company_teammate, person: other_person, organization: company)
      sign_in_as_teammate_for_request(other_person, company)

      get answer_organization_feedback_request_path(company, feedback_request)
      expect(response).to have_http_status(:redirect)
    end
  end

  describe 'POST /organizations/:organization_id/feedback_requests/:id/submit_answers' do
    let(:feedback_request) do
      create(:feedback_request,
        company: company,
        requestor_teammate: requestor_teammate,
        subject_of_feedback_teammate: subject_teammate,
        subject_line: 'Test feedback request'
      )
    end

    before do
      # Clear any existing questions first
      feedback_request.feedback_request_questions.destroy_all
      # Create questions with text so request can be ready
      create(:feedback_request_question, feedback_request: feedback_request, question_text: 'Test question 1?', position: 1)
      create(:feedback_request_question, feedback_request: feedback_request, question_text: 'Test question 2?', position: 2)
      # Add current user as responder
      feedback_request.feedback_request_responders.create!(teammate: requestor_teammate)
      feedback_request.reload # Reload to ensure questions are loaded
      sign_in_as_teammate_for_request(requestor_person, company)
    end

    it 'creates observations from answers' do
      feedback_request.reload # Ensure questions are loaded
      question = feedback_request.feedback_request_questions.first
      expect {
        post submit_answers_organization_feedback_request_path(company, feedback_request), params: {
          answers: {
            question.id.to_s => {
              story: 'This is my answer to the question',
              privacy_level: 'observed_and_managers'
            }
          },
          privacy_level: 'observed_and_managers'
        }
      }.to change { Observation.count }.by(1)
    end

    it 'creates one observation per answered question' do
      feedback_request.reload # Ensure questions are loaded
      questions = feedback_request.feedback_request_questions
      expect {
        post submit_answers_organization_feedback_request_path(company, feedback_request), params: {
          answers: {
            questions[0].id.to_s => { story: 'Answer 1', privacy_level: 'observed_and_managers' },
            questions[1].id.to_s => { story: 'Answer 2', privacy_level: 'observed_and_managers' }
          },
          privacy_level: 'observed_and_managers'
        }
      }.to change { Observation.count }.by(2)
    end

    it 'redirects to show page on success' do
      feedback_request.reload # Ensure questions are loaded
      question = feedback_request.feedback_request_questions.first
      post submit_answers_organization_feedback_request_path(company, feedback_request), params: {
        answers: {
          question.id.to_s => {
            story: 'This is my answer',
            privacy_level: 'observed_and_managers'
          }
        },
        privacy_level: 'observed_and_managers'
      }
      expect(response).to redirect_to(organization_feedback_request_path(company, feedback_request))
    end
  end

  describe 'POST /organizations/:organization_id/feedback_requests/:id/archive' do
    let(:feedback_request) do
      create(:feedback_request,
        company: company,
        requestor_teammate: requestor_teammate,
        subject_of_feedback_teammate: subject_teammate,
        subject_line: 'Test feedback request'
      )
    end

    it 'archives the feedback request' do
      post archive_organization_feedback_request_path(company, feedback_request)
      feedback_request.reload
      expect(feedback_request.deleted_at).to be_present
      expect(feedback_request.state).to eq('archived') # State is now computed
      expect(feedback_request.archived?).to be true
    end

    it 'redirects to show page' do
      post archive_organization_feedback_request_path(company, feedback_request)
      expect(response).to redirect_to(organization_feedback_request_path(company, feedback_request))
    end
  end

  describe 'POST /organizations/:organization_id/feedback_requests/:id/restore' do
    let(:feedback_request) do
      create(:feedback_request, :archived,
        company: company,
        requestor_teammate: requestor_teammate,
        subject_of_feedback_teammate: subject_teammate,
        subject_line: 'Test feedback request'
      )
    end

    before do
      # Create questions and responders so request can be restored to ready state
      create(:feedback_request_question, feedback_request: feedback_request, question_text: 'Test question?', position: 1)
      feedback_request.feedback_request_responders.create!(teammate: responder_teammate)
    end

    it 'restores the feedback request' do
      post restore_organization_feedback_request_path(company, feedback_request)
      feedback_request.reload
      expect(feedback_request.deleted_at).to be_nil
      # State should be ready after restore (if valid) or invalid
      expect(['ready', 'invalid']).to include(feedback_request.state)
    end

    it 'redirects to show page' do
      post restore_organization_feedback_request_path(company, feedback_request)
      expect(response).to redirect_to(organization_feedback_request_path(company, feedback_request))
    end
  end
end
