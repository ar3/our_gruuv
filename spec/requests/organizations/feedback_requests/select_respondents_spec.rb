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
  let(:other_responder_person) { create(:person) }
  let(:other_responder_teammate) do
    CompanyTeammate.find_or_create_by!(person: other_responder_person, organization: company) do |t|
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
    other_responder_teammate.update!(organization: company) if other_responder_teammate.organization != company
    sign_in_as_teammate_for_request(requestor_person, company)
    create(:feedback_request_question, feedback_request: feedback_request, question_text: 'Test question?', position: 1)
  end

  describe 'GET /organizations/:organization_id/feedback_requests/:id/select_respondents' do
    it 'renders the who-can-respond page with open-to-anyone checkbox and selection toolbar' do
      get select_respondents_organization_feedback_request_path(company, feedback_request)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Who Can Respond')
      expect(response.body).to include('Step 4: Who Can Respond')
      expect(response.body).to include('Open to anyone with the link')
      expect(response.body).to include('selection-toolbar')
      expect(response.body).to include('Search teammates')
      expect(response.body).to include('Save who can respond')
      expect(response.body).to include('respondent_ids[]')
      expect(response.body).to include('name="open_to_anyone"')
    end

    it 'pre-checks existing respondents' do
      feedback_request.feedback_request_responders.create!(teammate_id: responder_teammate.id)
      get select_respondents_organization_feedback_request_path(company, feedback_request)
      expect(response.body).to include("id=\"respondent_#{responder_teammate.id}\"")
      expect(response.body).to match(/id="respondent_#{responder_teammate.id}"[^>]*checked/)
    end

    it 'requires authorization' do
      other_person = create(:person)
      sign_in_as_teammate_for_request(other_person, company)

      get select_respondents_organization_feedback_request_path(company, feedback_request)
      expect(response).to have_http_status(:redirect)
    end
  end

  describe 'PATCH /organizations/:organization_id/feedback_requests/:id/update_respondents' do
    it 'saves open request with named respondents' do
      expect {
        patch update_respondents_organization_feedback_request_path(company, feedback_request),
              params: { open_to_anyone: '1', respondent_ids: [responder_teammate.id, other_responder_teammate.id] }
      }.to change { FeedbackRequestResponder.count }.by(2)

      expect(response).to redirect_to(organization_feedback_request_path(company, feedback_request))
      expect(feedback_request.responders.reload).to contain_exactly(responder_teammate, other_responder_teammate)
      expect(feedback_request.reload.open_to_anyone).to be true
      expect(feedback_request.ready?).to be true
    end

    it 'saves open request without named respondents' do
      patch update_respondents_organization_feedback_request_path(company, feedback_request),
            params: { open_to_anyone: '1', respondent_ids: [] }

      expect(response).to redirect_to(organization_feedback_request_path(company, feedback_request))
      expect(feedback_request.reload.open_to_anyone).to be true
      expect(feedback_request.responders).to be_empty
      expect(feedback_request).to be_ready
    end

    it 'keeps named respondents when staying open' do
      feedback_request.feedback_request_responders.create!(teammate_id: responder_teammate.id)

      patch update_respondents_organization_feedback_request_path(company, feedback_request),
            params: { open_to_anyone: '1', respondent_ids: [responder_teammate.id] }

      expect(feedback_request.responders.reload).to contain_exactly(responder_teammate)
      expect(feedback_request.reload.open_to_anyone).to be true
    end

    it 'requires named respondents when closed' do
      patch update_respondents_organization_feedback_request_path(company, feedback_request),
            params: { open_to_anyone: '0', respondent_ids: [] }
      expect(response).to redirect_to(select_respondents_organization_feedback_request_path(company, feedback_request))
      expect(flash[:alert]).to include('named respondent')
    end

    it 'saves respondents-only with named people' do
      patch update_respondents_organization_feedback_request_path(company, feedback_request),
            params: { open_to_anyone: '0', respondent_ids: [responder_teammate.id] }

      expect(response).to redirect_to(organization_feedback_request_path(company, feedback_request))
      expect(feedback_request.reload.open_to_anyone).to be false
      expect(feedback_request.responders).to contain_exactly(responder_teammate)
      expect(feedback_request).to be_ready
    end

    it 'replaces the respondent set (adds and removes)' do
      feedback_request.feedback_request_responders.create!(teammate_id: responder_teammate.id)
      feedback_request.feedback_request_responders.create!(teammate_id: other_responder_teammate.id)

      patch update_respondents_organization_feedback_request_path(company, feedback_request),
            params: { open_to_anyone: '1', respondent_ids: [responder_teammate.id] }

      expect(feedback_request.responders.reload).to contain_exactly(responder_teammate)
    end

    it 'preserves completed_at when keeping an existing respondent' do
      completed_at = 2.days.ago
      feedback_request.feedback_request_responders.create!(teammate_id: responder_teammate.id, completed_at: completed_at)

      patch update_respondents_organization_feedback_request_path(company, feedback_request),
            params: { open_to_anyone: '1', respondent_ids: [responder_teammate.id, other_responder_teammate.id] }

      kept = feedback_request.feedback_request_responders.find_by!(teammate_id: responder_teammate.id)
      expect(kept.completed_at).to be_within(1.second).of(completed_at)
    end
  end
end
