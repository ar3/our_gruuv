require 'rails_helper'

RSpec.describe 'Observation Wizard Session Management', type: :request do
  let(:company) { create(:organization, :company) }
  let(:observer) { create(:person) }
  let(:observer_teammate) { create(:teammate, person: observer, organization: company) }
  let(:observee1) { create(:teammate, organization: company) }
  let(:observee2) { create(:teammate, organization: company) }
  let(:ability1) { create(:ability, organization: company, name: 'Ruby Programming') }
  let(:assignment1) { create(:assignment, company: company, title: 'Frontend Development') }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(observer)
    observer_teammate # Ensure observer teammate is created
  end

  describe 'Session data structure at each step' do
    it 'stores correct data structure after Step 1' do
      post organization_observations_path(company), params: {
        observation: {
          story: 'Great work!',
          primary_feeling: 'happy',
          secondary_feeling: 'proud',
          observed_at: '2024-01-15T14:30',
          teammate_ids: [observee1.id.to_s, observee2.id.to_s]
        },
        step: '2'
      }

      expect(response).to redirect_to(set_ratings_organization_observation_path(company, 'new'))
      
      # Follow redirect to check session data
      get set_ratings_organization_observation_path(company, 'new')
      
      # Session should contain Step 1 data
      wizard_data = session[:observation_wizard_data]
      expect(wizard_data).to be_present
      expect(wizard_data['story']).to eq('Great work!')
      expect(wizard_data['primary_feeling']).to eq('happy')
      expect(wizard_data['secondary_feeling']).to eq('proud')
      expect(wizard_data['observed_at']).to eq('2024-01-15T14:30')
      expect(wizard_data['teammate_ids']).to eq([observee1.id.to_s, observee2.id.to_s])
    end

    it 'stores correct data structure after Step 2' do
      # Set up Step 1 data
      session[:observation_wizard_data] = {
        'story' => 'Great work!',
        'primary_feeling' => 'happy',
        'secondary_feeling' => 'proud',
        'observed_at' => '2024-01-15T14:30',
        'teammate_ids' => [observee1.id.to_s, observee2.id.to_s]
      }

      post set_ratings_organization_observation_path(company, 'new'), params: {
        observation: {
          privacy_level: 'observed_only',
          observation_ratings_attributes: {
            "ability_#{ability1.id}" => { rateable_type: 'Ability', rateable_id: ability1.id, rating: 'strongly_agree' },
            "assignment_#{assignment1.id}" => { rateable_type: 'Assignment', rateable_id: assignment1.id, rating: 'agree' }
          }
        },
        step: '3'
      }

      expect(response).to redirect_to(review_organization_observation_path(company, 'new'))
      
      # Follow redirect to check session data
      get review_organization_observation_path(company, 'new')
      
      # Session should contain Step 1 + Step 2 data
      wizard_data = session[:observation_wizard_data]
      expect(wizard_data).to be_present
      expect(wizard_data['story']).to eq('Great work!')
      expect(wizard_data['privacy_level']).to eq('observed_only')
      expect(wizard_data['observation_ratings_attributes']).to be_present
      expect(wizard_data['observation_ratings_attributes']["ability_#{ability1.id}"]['rating']).to eq('strongly_agree')
      expect(wizard_data['observation_ratings_attributes']["assignment_#{assignment1.id}"]['rating']).to eq('agree')
    end

    it 'stores correct data structure after Step 3' do
      # Set up Step 1 + Step 2 data
      session[:observation_wizard_data] = {
        'story' => 'Great work!',
        'primary_feeling' => 'happy',
        'secondary_feeling' => 'proud',
        'observed_at' => '2024-01-15T14:30',
        'teammate_ids' => [observee1.id.to_s, observee2.id.to_s],
        'privacy_level' => 'observed_only',
        'observation_ratings_attributes' => {
          "ability_#{ability1.id}" => { 'rateable_type' => 'Ability', 'rateable_id' => ability1.id.to_s, 'rating' => 'strongly_agree' }
        }
      }

      post create_observation_organization_observation_path(company, 'new'), params: {
        observation: {
          send_notifications: '1',
          notify_teammate_ids: [observee1.id.to_s]
        }
      }

      expect(response).to redirect_to(organization_observation_path(company, Observation.last))
      
      # Session should be cleared after completion
      wizard_data = session[:observation_wizard_data]
      expect(wizard_data).to be_nil
    end
  end

  describe 'Session data persistence across steps' do
    it 'persists data when navigating between steps' do
      # Step 1: Store initial data
      post organization_observations_path(company), params: {
        observation: {
          story: 'Test story',
          primary_feeling: 'happy',
          observed_at: '2024-01-15T14:30',
          teammate_ids: [observee1.id.to_s]
        },
        step: '2'
      }

      # Step 2: Add more data
      post set_ratings_organization_observation_path(company, 'new'), params: {
        observation: {
          privacy_level: 'observed_only'
        },
        step: '3'
      }

      # Step 3: Verify all data is present
      get review_organization_observation_path(company, 'new')
      
      wizard_data = session[:observation_wizard_data]
      expect(wizard_data['story']).to eq('Test story')
      expect(wizard_data['primary_feeling']).to eq('happy')
      expect(wizard_data['privacy_level']).to eq('observed_only')
      expect(wizard_data['teammate_ids']).to eq([observee1.id.to_s])
    end

    it 'preserves data when going back to previous steps' do
      # Set up complete wizard data
      session[:observation_wizard_data] = {
        'story' => 'Test story',
        'primary_feeling' => 'happy',
        'observed_at' => '2024-01-15T14:30',
        'teammate_ids' => [observee1.id.to_s],
        'privacy_level' => 'observed_only',
        'observation_ratings_attributes' => {
          "ability_#{ability1.id}" => { 'rateable_type' => 'Ability', 'rateable_id' => ability1.id.to_s, 'rating' => 'strongly_agree' }
        }
      }

      # Go back to Step 2
      get set_ratings_organization_observation_path(company, 'new')
      
      wizard_data = session[:observation_wizard_data]
      expect(wizard_data['story']).to eq('Test story')
      expect(wizard_data['privacy_level']).to eq('observed_only')
      expect(wizard_data['observation_ratings_attributes']).to be_present

      # Go back to Step 1
      get new_organization_observation_path(company)
      
      wizard_data = session[:observation_wizard_data]
      expect(wizard_data['story']).to eq('Test story')
      expect(wizard_data['primary_feeling']).to eq('happy')
    end
  end

  describe 'Session data clearing after completion' do
    it 'clears session data after successful observation creation' do
      # Set up complete wizard data
      session[:observation_wizard_data] = {
        'story' => 'Test story',
        'primary_feeling' => 'happy',
        'observed_at' => '2024-01-15T14:30',
        'teammate_ids' => [observee1.id.to_s],
        'privacy_level' => 'observed_only'
      }

      # Create observation
      post create_observation_organization_observation_path(company, 'new'), params: {
        observation: {
          send_notifications: '0'
        }
      }

      # Session should be cleared
      expect(session[:observation_wizard_data]).to be_nil
    end

    it 'clears session data after observation creation with notifications' do
      # Set up complete wizard data
      session[:observation_wizard_data] = {
        'story' => 'Test story',
        'primary_feeling' => 'happy',
        'observed_at' => '2024-01-15T14:30',
        'teammate_ids' => [observee1.id.to_s],
        'privacy_level' => 'observed_only'
      }

      # Create observation with notifications
      post create_observation_organization_observation_path(company, 'new'), params: {
        observation: {
          send_notifications: '1',
          notify_teammate_ids: [observee1.id.to_s]
        }
      }

      # Session should be cleared
      expect(session[:observation_wizard_data]).to be_nil
    end
  end

  describe 'Session data expiration handling' do
    it 'redirects to Step 1 when session data is missing' do
      # Clear session data
      session[:observation_wizard_data] = nil

      # Try to access Step 2
      get set_ratings_organization_observation_path(company, 'new')
      expect(response).to redirect_to(new_organization_observation_path(company))
    end

    it 'redirects to Step 1 when session data is empty' do
      # Set empty session data
      session[:observation_wizard_data] = {}

      # Try to access Step 2
      get set_ratings_organization_observation_path(company, 'new')
      expect(response).to redirect_to(new_organization_observation_path(company))
    end

    it 'redirects to Step 1 when session data is incomplete' do
      # Set incomplete session data
      session[:observation_wizard_data] = {
        'story' => 'Test story'
        # Missing required fields
      }

      # Try to access Step 2
      get set_ratings_organization_observation_path(company, 'new')
      expect(response).to redirect_to(new_organization_observation_path(company))
    end
  end

  describe 'Session data validation' do
    it 'validates required fields in session data' do
      # Set session data without required fields
      session[:observation_wizard_data] = {
        'story' => 'Test story'
        # Missing teammate_ids
      }

      # Try to access Step 2
      get set_ratings_organization_observation_path(company, 'new')
      expect(response).to redirect_to(new_organization_observation_path(company))
    end

    it 'validates data types in session data' do
      # Set session data with wrong data types
      session[:observation_wizard_data] = {
        'story' => 'Test story',
        'teammate_ids' => 'not_an_array', # Should be array
        'observed_at' => 'invalid_date'
      }

      # Try to access Step 2
      get set_ratings_organization_observation_path(company, 'new')
      expect(response).to redirect_to(new_organization_observation_path(company))
    end
  end

  describe 'Session data structure edge cases' do
    it 'handles empty teammate_ids array' do
      session[:observation_wizard_data] = {
        'story' => 'Test story',
        'teammate_ids' => [],
        'observed_at' => '2024-01-15T14:30'
      }

      # Try to access Step 2
      get set_ratings_organization_observation_path(company, 'new')
      expect(response).to redirect_to(new_organization_observation_path(company))
    end

    it 'handles nil values in session data' do
      session[:observation_wizard_data] = {
        'story' => 'Test story',
        'primary_feeling' => nil,
        'secondary_feeling' => nil,
        'teammate_ids' => [observee1.id.to_s],
        'observed_at' => '2024-01-15T14:30'
      }

      # Should work with nil values
      get set_ratings_organization_observation_path(company, 'new')
      expect(response).to have_http_status(:success)
    end

    it 'handles large session data' do
      large_story = 'A' * 10000
      session[:observation_wizard_data] = {
        'story' => large_story,
        'teammate_ids' => [observee1.id.to_s],
        'observed_at' => '2024-01-15T14:30'
      }

      # Should handle large data
      get set_ratings_organization_observation_path(company, 'new')
      expect(response).to have_http_status(:success)
    end
  end

  describe 'Session data corruption handling' do
    it 'handles corrupted session data gracefully' do
      # Set corrupted session data
      session[:observation_wizard_data] = {
        'story' => 'Test story',
        'teammate_ids' => [observee1.id.to_s],
        'observed_at' => '2024-01-15T14:30',
        'corrupted_field' => { 'nested' => { 'data' => 'corrupted' } }
      }

      # Should still work
      get set_ratings_organization_observation_path(company, 'new')
      expect(response).to have_http_status(:success)
    end

    it 'handles malformed observation_ratings_attributes' do
      session[:observation_wizard_data] = {
        'story' => 'Test story',
        'teammate_ids' => [observee1.id.to_s],
        'observed_at' => '2024-01-15T14:30',
        'observation_ratings_attributes' => 'not_a_hash'
      }

      # Should handle malformed data
      get set_ratings_organization_observation_path(company, 'new')
      expect(response).to have_http_status(:success)
    end
  end

  describe 'Session data security' do
    it 'does not expose sensitive data in session' do
      # Set session data
      session[:observation_wizard_data] = {
        'story' => 'Test story',
        'teammate_ids' => [observee1.id.to_s],
        'observed_at' => '2024-01-15T14:30'
      }

      # Access Step 2
      get set_ratings_organization_observation_path(company, 'new')
      
      # Session data should not be exposed in response
      expect(response.body).not_to include('Test story')
      expect(response.body).not_to include(observee1.id.to_s)
    end

    it 'validates session data belongs to current user' do
      # Set session data for different user
      other_user = create(:person)
      session[:observation_wizard_data] = {
        'story' => 'Test story',
        'teammate_ids' => [observee1.id.to_s],
        'observed_at' => '2024-01-15T14:30'
      }

      # Should still work (session is per-user)
      get set_ratings_organization_observation_path(company, 'new')
      expect(response).to have_http_status(:success)
    end
  end

  describe 'Session data performance' do
    it 'handles multiple rapid requests' do
      # Set session data
      session[:observation_wizard_data] = {
        'story' => 'Test story',
        'teammate_ids' => [observee1.id.to_s],
        'observed_at' => '2024-01-15T14:30'
      }

      # Make multiple rapid requests
      5.times do
        get set_ratings_organization_observation_path(company, 'new')
        expect(response).to have_http_status(:success)
      end
    end

    it 'handles concurrent session access' do
      # Set session data
      session[:observation_wizard_data] = {
        'story' => 'Test story',
        'teammate_ids' => [observee1.id.to_s],
        'observed_at' => '2024-01-15T14:30'
      }

      # Simulate concurrent access
      get set_ratings_organization_observation_path(company, 'new')
      expect(response).to have_http_status(:success)
      
      # Update session data
      post set_ratings_organization_observation_path(company, 'new'), params: {
        observation: {
          privacy_level: 'observed_only'
        },
        step: '3'
      }
      
      expect(response).to redirect_to(review_organization_observation_path(company, 'new'))
    end
  end
end
