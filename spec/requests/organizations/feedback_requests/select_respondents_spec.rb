require 'rails_helper'

RSpec.describe 'Organizations::FeedbackRequests::SelectRespondents', type: :request do
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
  let(:responder_person) { create(:person) }
  let(:responder_teammate) do
    CompanyTeammate.find_or_create_by!(person: responder_person, organization: company) do |t|
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

  before do
    requestor_teammate.update!(organization: company) if requestor_teammate.organization != company
    subject_teammate.update!(organization: company) if subject_teammate.organization != company
    responder_teammate.update!(organization: company) if responder_teammate.organization != company
    sign_in_as_teammate_for_request(requestor_person, company)
    # Create questions with text so request can be ready
    create(:feedback_request_question, feedback_request: feedback_request, question_text: 'Test question?', position: 1)
  end

  describe 'GET /organizations/:organization_id/feedback_requests/:id/select_respondents' do
    it 'renders the select_respondents page' do
      get select_respondents_organization_feedback_request_path(company, feedback_request)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Select Respondents')
    end

    it 'renders the wizard header' do
      get select_respondents_organization_feedback_request_path(company, feedback_request)
      expect(response.body).to include('Step 4: Select Respondents')
    end

    it 'renders the multi-teammate selector (Add button and selected list area)' do
      get select_respondents_organization_feedback_request_path(company, feedback_request)
      expect(response.body).to include('Add')
      expect(response.body).to include('Save Feedback Request')
    end

    it 'requires authorization' do
      other_person = create(:person)
      sign_in_as_teammate_for_request(other_person, company)

      get select_respondents_organization_feedback_request_path(company, feedback_request)
      expect(response).to have_http_status(:redirect)
    end
  end

  describe 'POST /organizations/:organization_id/feedback_requests/:id/add_respondent' do
    it 'adds the teammate as a responder and redirects to select_respondents' do
      expect {
        post add_respondent_organization_feedback_request_path(company, feedback_request), params: { respondent_id: responder_teammate.id }
      }.to change { FeedbackRequestResponder.count }.by(1)
      expect(response).to redirect_to(select_respondents_organization_feedback_request_path(company, feedback_request))
      expect(feedback_request.responders.reload).to include(responder_teammate)
    end

    it 'redirects with alert when respondent_id is blank' do
      post add_respondent_organization_feedback_request_path(company, feedback_request), params: { respondent_id: '' }
      expect(response).to redirect_to(select_respondents_organization_feedback_request_path(company, feedback_request))
      expect(flash[:alert]).to include('select a teammate')
    end

    it 'does nothing when teammate is already a responder' do
      feedback_request.feedback_request_responders.create!(teammate_id: responder_teammate.id)
      expect {
        post add_respondent_organization_feedback_request_path(company, feedback_request), params: { respondent_id: responder_teammate.id }
      }.not_to change { FeedbackRequestResponder.count }
      expect(response).to redirect_to(select_respondents_organization_feedback_request_path(company, feedback_request))
    end
  end

  describe 'DELETE /organizations/:organization_id/feedback_requests/:id/remove_respondent' do
    it 'removes the teammate from responders and redirects to select_respondents' do
      feedback_request.feedback_request_responders.create!(teammate_id: responder_teammate.id)
      expect {
        delete remove_respondent_organization_feedback_request_path(company, feedback_request), params: { respondent_id: responder_teammate.id }
      }.to change { FeedbackRequestResponder.count }.by(-1)
      expect(response).to redirect_to(select_respondents_organization_feedback_request_path(company, feedback_request))
      expect(feedback_request.responders.reload).not_to include(responder_teammate)
    end
  end

  describe 'PATCH /organizations/:organization_id/feedback_requests/:id/update_respondents' do
    it 'finalizes when at least one respondent is present and redirects to show' do
      feedback_request.feedback_request_responders.create!(teammate_id: responder_teammate.id)
      patch update_respondents_organization_feedback_request_path(company, feedback_request)
      expect(response).to redirect_to(organization_feedback_request_path(company, feedback_request))
    end

    it 'redirects with error if no respondents selected' do
      patch update_respondents_organization_feedback_request_path(company, feedback_request)
      expect(response).to redirect_to(select_respondents_organization_feedback_request_path(company, feedback_request))
      expect(flash[:alert]).to include('select at least one respondent')
    end

    it 'validates state after adding respondents and finalizing' do
      post add_respondent_organization_feedback_request_path(company, feedback_request), params: { respondent_id: responder_teammate.id }
      follow_redirect!
      patch update_respondents_organization_feedback_request_path(company, feedback_request)
      feedback_request.reload
      expect(feedback_request.ready?).to be true
    end
  end
end
