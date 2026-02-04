require 'rails_helper'

RSpec.describe 'InterestSubmissions#index', type: :request do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:other_person) { create(:person) }
  
  describe 'GET /interest' do
    context 'when user is unauthenticated' do
      it 'allows access to the index page' do
        get interest_submissions_path
        expect(response).to have_http_status(:success)
      end
      
      it 'shows no interest submissions for unauthenticated users' do
        create(:interest_submission, person: person, thing_interested_in: 'Test submission')
        
        get interest_submissions_path
        
        expect(response).to have_http_status(:success)
        expect(response.body).to include('Login or create an account to submit your ideas')
        expect(response.body).not_to include('Test submission')
      end
      
      it 'displays change logs' do
        change_log = create(:change_log, description: 'Test change log')
        
        get interest_submissions_path
        
        expect(response).to have_http_status(:success)
        expect(response.body).to include('Recent Changes')
        expect(response.body).to include('Test change log')
      end
      
      it 'displays spotlight stats for change logs' do
        create(:change_log, :new_value, :past_90_days)
        create(:change_log, :major_enhancement, :past_90_days)
        create(:change_log, :minor_enhancement, :past_90_days)
        create(:change_log, :bug_fix, :past_90_days)
        
        get interest_submissions_path
        
        expect(response).to have_http_status(:success)
        expect(response.body).to include('New Value')
        expect(response.body).to include('Major Enhancement')
        expect(response.body).to include('Minor Enhancement')
        expect(response.body).to include('Bug Fix')
      end
    end
    
    context 'when user is authenticated' do
      before do
        sign_in_as_teammate_for_request(person, organization)
      end
      
      it 'allows access to the index page' do
        get interest_submissions_path
        expect(response).to have_http_status(:success)
      end
      
      it 'shows only the user\'s own interest submissions' do
        my_submission = create(:interest_submission, person: person, thing_interested_in: 'My submission')
        other_submission = create(:interest_submission, person: other_person, thing_interested_in: 'Other submission')
        
        get interest_submissions_path
        
        expect(response).to have_http_status(:success)
        expect(response.body).to include('My submission')
        expect(response.body).not_to include('Other submission')
      end
      
      it 'shows empty state when user has no submissions' do
        get interest_submissions_path
        
        expect(response).to have_http_status(:success)
        expect(response.body).to include("You haven't submitted any ideas yet")
      end
      
      it 'displays change logs with pagination' do
        create_list(:change_log, 30)
        
        get interest_submissions_path
        
        expect(response).to have_http_status(:success)
        expect(response.body).to include('Recent Changes')
        expect(assigns(:change_logs).count).to eq(25) # Pagy default items per page
      end
      
      context 'when user is an admin' do
        let(:admin_person) { create(:person, :admin) }
        
        before do
          sign_in_as_teammate_for_request(admin_person, organization)
        end
        
        it 'shows "New Change Log" button' do
          get interest_submissions_path
          
          expect(response).to have_http_status(:success)
          expect(response.body).to include('New Change Log')
        end
        
        it 'shows edit links for change logs' do
          change_log = create(:change_log)
          
          get interest_submissions_path
          
          expect(response).to have_http_status(:success)
          expect(response.body).to include(edit_change_log_path(change_log))
        end
      end
      
      context 'when user is not an admin' do
        it 'does not show "New Change Log" button' do
          get interest_submissions_path
          
          expect(response).to have_http_status(:success)
          expect(response.body).not_to include('New Change Log')
        end
        
        it 'does not show edit links for change logs' do
          change_log = create(:change_log)
          
          get interest_submissions_path
          
          expect(response).to have_http_status(:success)
          expect(response.body).not_to include(edit_change_log_path(change_log))
        end
      end
    end
  end
end

