require 'rails_helper'

RSpec.describe Organizations::Assignments::AssignmentOutcomesController, type: :controller do
  let(:organization) { create(:organization, :company) }
  let(:assignment) { create(:assignment, company: organization) }
  let(:assignment_outcome) { create(:assignment_outcome, assignment: assignment, description: 'Original Description', outcome_type: 'quantitative') }
  
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

  describe 'GET #edit' do
    context 'when user is admin' do
      before do
        admin_teammate
        sign_in_as_teammate(admin, organization)
      end

      it 'returns success' do
        get :edit, params: { organization_id: organization.id, assignment_id: assignment.id, id: assignment_outcome.id }
        expect(response).to have_http_status(:success)
      end

      it 'assigns the assignment outcome' do
        get :edit, params: { organization_id: organization.id, assignment_id: assignment.id, id: assignment_outcome.id }
        expect(assigns(:assignment_outcome)).to eq(assignment_outcome)
      end

      it 'uses overlay layout' do
        get :edit, params: { organization_id: organization.id, assignment_id: assignment.id, id: assignment_outcome.id }
        expect(response).to render_template(layout: 'overlay')
      end
    end

    context 'when user has MAAP permission' do
      before do
        maap_teammate
        sign_in_as_teammate(maap_person, organization)
      end

      it 'returns success' do
        get :edit, params: { organization_id: organization.id, assignment_id: assignment.id, id: assignment_outcome.id }
        expect(response).to have_http_status(:success)
      end
    end

    context 'when user does not have MAAP permission' do
      before do
        regular_teammate
        sign_in_as_teammate(regular_person, organization)
      end

      it 'denies access' do
        get :edit, params: { organization_id: organization.id, assignment_id: assignment.id, id: assignment_outcome.id }
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe 'PATCH #update' do
    let(:update_params) do
      {
        assignment_outcome: {
          description: 'Updated Description',
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
        sign_in_as_teammate(admin, organization)
      end

      it 'updates the assignment outcome' do
        patch :update, params: {
          organization_id: organization.id,
          assignment_id: assignment.id,
          id: assignment_outcome.id
        }.merge(update_params)
        
        assignment_outcome.reload
        expect(assignment_outcome.description).to eq('Updated Description')
        expect(assignment_outcome.outcome_type).to eq('sentiment')
        expect(assignment_outcome.progress_report_url).to eq('https://example.com/report')
        expect(assignment_outcome.management_relationship_filter).to eq('direct_employee')
        expect(assignment_outcome.team_relationship_filter).to eq('same_team')
        expect(assignment_outcome.consumer_assignment_filter).to eq('active_consumer')
      end

      it 'redirects to assignment show page with notice' do
        patch :update, params: {
          organization_id: organization.id,
          assignment_id: assignment.id,
          id: assignment_outcome.id
        }.merge(update_params)
        
        expect(response).to redirect_to(organization_assignment_path(organization, assignment))
        expect(flash[:notice]).to eq('Outcome was successfully updated.')
      end

      it 'normalizes empty strings to nil for filter fields' do
        # Set some filter values first
        assignment_outcome.update!(
          management_relationship_filter: 'direct_employee',
          team_relationship_filter: 'same_team',
          consumer_assignment_filter: 'active_consumer'
        )
        
        # Update with empty strings
        patch :update, params: {
          organization_id: organization.id,
          assignment_id: assignment.id,
          id: assignment_outcome.id,
          assignment_outcome: {
            description: assignment_outcome.description,
            outcome_type: assignment_outcome.outcome_type,
            management_relationship_filter: '',
            team_relationship_filter: '',
            consumer_assignment_filter: ''
          }
        }
        
        assignment_outcome.reload
        expect(assignment_outcome.management_relationship_filter).to be_nil
        expect(assignment_outcome.team_relationship_filter).to be_nil
        expect(assignment_outcome.consumer_assignment_filter).to be_nil
      end
    end

    context 'when user has MAAP permission' do
      before do
        maap_teammate
        sign_in_as_teammate(maap_person, organization)
      end

      it 'updates the assignment outcome' do
        patch :update, params: {
          organization_id: organization.id,
          assignment_id: assignment.id,
          id: assignment_outcome.id
        }.merge(update_params)
        
        assignment_outcome.reload
        expect(assignment_outcome.description).to eq('Updated Description')
      end
    end

    context 'when user does not have MAAP permission' do
      before do
        regular_teammate
        sign_in_as_teammate(regular_person, organization)
      end

      it 'denies access' do
        patch :update, params: {
          organization_id: organization.id,
          assignment_id: assignment.id,
          id: assignment_outcome.id
        }.merge(update_params)
        
        expect(response).to redirect_to(root_path)
        assignment_outcome.reload
        expect(assignment_outcome.description).to eq('Original Description')
      end
    end

    context 'when update fails validation' do
      before do
        admin_teammate
        sign_in_as_teammate(admin, organization)
      end

      it 'renders edit with errors' do
        patch :update, params: {
          organization_id: organization.id,
          assignment_id: assignment.id,
          id: assignment_outcome.id,
          assignment_outcome: {
            description: '',
            outcome_type: 'quantitative'
          }
        }
        
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to render_template(:edit)
      end
    end
  end
end
