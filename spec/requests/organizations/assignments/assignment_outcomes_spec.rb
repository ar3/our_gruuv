require 'rails_helper'

RSpec.describe 'Organizations::Assignments::AssignmentOutcomes', type: :request do
  let(:organization) { create(:organization, :company) }
  let(:assignment) { create(:assignment, company: organization) }
  let(:assignment_outcome) { create(:assignment_outcome, assignment: assignment, description: 'Test Outcome', outcome_type: 'quantitative') }
  
  let(:admin) { create(:person, :admin) }
  let(:maap_person) { create(:person) }
  let(:regular_person) { create(:person) }
  
  let(:admin_teammate) { create(:teammate, person: admin, organization: organization) }
  let(:maap_teammate) { create(:teammate, person: maap_person, organization: organization, can_manage_maap: true) }
  let(:regular_teammate) { create(:teammate, person: regular_person, organization: organization) }

  before do
    PaperTrail.enabled = false
  end

  after do
    PaperTrail.enabled = true
  end

  describe 'GET /organizations/:organization_id/assignments/:assignment_id/assignment_outcomes/:id/edit' do
    context 'when user is admin' do
      before do
        admin_teammate
        sign_in_as_teammate_for_request(admin, organization)
      end

      it 'returns success' do
        get edit_organization_assignment_assignment_outcome_path(organization, assignment, assignment_outcome)
        expect(response).to have_http_status(:success)
      end

      it 'renders the edit template' do
        get edit_organization_assignment_assignment_outcome_path(organization, assignment, assignment_outcome)
        expect(response.body).to include('Edit Outcome')
        expect(response.body).to include('Description')
        expect(response.body).to include('Type')
      end

      it 'shows the current outcome description' do
        get edit_organization_assignment_assignment_outcome_path(organization, assignment, assignment_outcome)
        expect(response.body).to include(assignment_outcome.description)
      end

      it 'shows measurement fields' do
        get edit_organization_assignment_assignment_outcome_path(organization, assignment, assignment_outcome)
        expect(response.body).to include('Progress Report URL')
        expect(response.body).to include('Who to Ask: Management Relationship')
        expect(response.body).to include('Who to Ask: Team Relationship')
        expect(response.body).to include('Who to Ask: Consumer Assignment Relationship')
      end
    end

    context 'when user has MAAP permission' do
      before do
        maap_teammate
        sign_in_as_teammate_for_request(maap_person, organization)
      end

      it 'returns success' do
        get edit_organization_assignment_assignment_outcome_path(organization, assignment, assignment_outcome)
        expect(response).to have_http_status(:success)
      end

      it 'shows enabled save button' do
        get edit_organization_assignment_assignment_outcome_path(organization, assignment, assignment_outcome)
        expect(response.body).to include('Save Outcome')
        expect(response.body).not_to include('disabled')
      end
    end

    context 'when user does not have MAAP permission' do
      before do
        regular_teammate
        sign_in_as_teammate_for_request(regular_person, organization)
      end

      it 'denies access' do
        get edit_organization_assignment_assignment_outcome_path(organization, assignment, assignment_outcome)
        expect(response).to redirect_to(root_path)
      end
    end

    context 'with sentiment outcome' do
      let(:sentiment_outcome) { create(:assignment_outcome, assignment: assignment, description: 'Sentiment Outcome', outcome_type: 'sentiment') }

      before do
        admin_teammate
        sign_in_as_teammate_for_request(admin, organization)
      end

      it 'shows measurement fields for sentiment outcomes' do
        get edit_organization_assignment_assignment_outcome_path(organization, assignment, sentiment_outcome)
        expect(response.body).to include('Progress Report URL')
        expect(response.body).to include('Who to Ask: Management Relationship')
        expect(response.body).to include('Who to Ask: Team Relationship')
        expect(response.body).to include('Who to Ask: Consumer Assignment Relationship')
      end
    end
  end

  describe 'PATCH /organizations/:organization_id/assignments/:assignment_id/assignment_outcomes/:id' do
    let(:update_params) do
      {
        assignment_outcome: {
          description: 'Updated Outcome Description',
          outcome_type: 'sentiment',
          progress_report_url: 'https://example.com/report',
          management_relationship_filter: 'direct_employee',
          team_relationship_filter: 'same_team',
          consumer_assignment_filter: 'active_consumer'
        }
      }
    end

    context 'when user is admin' do
      before do
        admin_teammate
        sign_in_as_teammate_for_request(admin, organization)
      end

      it 'updates the outcome' do
        patch organization_assignment_assignment_outcome_path(organization, assignment, assignment_outcome), params: update_params
        
        assignment_outcome.reload
        expect(assignment_outcome.description).to eq('Updated Outcome Description')
        expect(assignment_outcome.outcome_type).to eq('sentiment')
        expect(assignment_outcome.progress_report_url).to eq('https://example.com/report')
        expect(assignment_outcome.management_relationship_filter).to eq('direct_employee')
        expect(assignment_outcome.team_relationship_filter).to eq('same_team')
        expect(assignment_outcome.consumer_assignment_filter).to eq('active_consumer')
      end

      it 'redirects to assignments index' do
        patch organization_assignment_assignment_outcome_path(organization, assignment, assignment_outcome), params: update_params
        expect(response).to have_http_status(:redirect)
        expect(response.location).to include(organization_assignments_path(organization))
      end

      it 'shows success notice' do
        patch organization_assignment_assignment_outcome_path(organization, assignment, assignment_outcome), params: update_params
        follow_redirect!
        expect(response.body).to include('Outcome was successfully updated')
      end
    end

    context 'when user has MAAP permission' do
      before do
        maap_teammate
        sign_in_as_teammate_for_request(maap_person, organization)
      end

      it 'updates the outcome' do
        patch organization_assignment_assignment_outcome_path(organization, assignment, assignment_outcome), params: update_params
        
        assignment_outcome.reload
        expect(assignment_outcome.description).to eq('Updated Outcome Description')
      end
    end

    context 'when user does not have MAAP permission' do
      before do
        regular_teammate
        sign_in_as_teammate_for_request(regular_person, organization)
      end

      it 'denies access' do
        patch organization_assignment_assignment_outcome_path(organization, assignment, assignment_outcome), params: update_params
        
        expect(response).to redirect_to(root_path)
        assignment_outcome.reload
        expect(assignment_outcome.description).to eq('Test Outcome')
      end
    end

    context 'when validation fails' do
      before do
        admin_teammate
        sign_in_as_teammate_for_request(admin, organization)
      end

      it 'renders edit with errors' do
        patch organization_assignment_assignment_outcome_path(organization, assignment, assignment_outcome), params: {
          assignment_outcome: {
            description: '',
            outcome_type: 'quantitative'
          }
        }
        
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('Edit Outcome')
      end
    end
  end
end
