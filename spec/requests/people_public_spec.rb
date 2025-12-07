require 'rails_helper'

RSpec.describe 'Public Person View', type: :request do
  let(:person) { create(:person, first_name: 'John', last_name: 'Doe') }

  describe 'GET /people/:id/public' do
    it 'renders successfully without authentication' do
      get public_person_path(person)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('John D.')
    end

    it 'renders successfully even when person has no teammates' do
      # Person with no teammates - this is the edge case that was failing
      get public_person_path(person)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('No public observations yet')
      expect(response.body).to include('No milestones attained yet')
    end

    it 'renders successfully when person has teammates but no observations or milestones' do
      create(:teammate, person: person, organization: create(:organization, :company))
      get public_person_path(person)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('John D.')
    end

    it 'renders successfully with observations and milestones' do
      organization = create(:organization, :company)
      teammate = create(:teammate, person: person, organization: organization)
      
      # Create a public observation
      observer = create(:person)
      observation = create(:observation,
        observer: observer,
        company: organization,
        privacy_level: 'public_to_world',
        published_at: 1.day.ago,
        observed_at: 1.day.ago
      )
      create(:observee, observation: observation, teammate: teammate)
      
      # Create a milestone (factory will create certified_by automatically)
      ability = create(:ability, organization: organization)
      create(:teammate_milestone,
        teammate: teammate,
        ability: ability,
        milestone_level: 3,
        attained_at: 1.month.ago
      )
      
      # Reload person to ensure associations are fresh
      person.reload
      
      get public_person_path(person)
      expect(response).to have_http_status(:success)
      # Just verify it renders without nil errors - the main goal
      expect(response.body).to include('John D.')
    end

    it 'shows teammate link when logged in user shares organization' do
      organization = create(:organization, :company)
      # Create a logged-in user in the same organization
      logged_in_person = create(:person)
      logged_in_teammate = create(:teammate, person: logged_in_person, organization: organization)
      # Create employment tenure for logged in person
      create(:employment_tenure, teammate: logged_in_teammate, company: organization, started_at: 1.year.ago)
      logged_in_teammate.update!(first_employed_at: 1.year.ago)
      
      # Create employment tenure for the person being viewed
      person_teammate = create(:teammate, person: person, organization: organization)
      create(:employment_tenure, teammate: person_teammate, company: organization, started_at: 1.year.ago)
      person_teammate.update!(first_employed_at: 1.year.ago)
      
      # Sign in
      sign_in_as_teammate_for_request(logged_in_person, organization)
      
      get public_person_path(person)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('View Teammate Profile')
      expect(response.body).to include(teammate_organization_person_path(organization, person))
    end

    it 'does not show teammate link when user is not logged in' do
      get public_person_path(person)
      expect(response).to have_http_status(:success)
      expect(response.body).not_to include('View Teammate Profile')
    end

    it 'does not show teammate link when user is in different organization' do
      # Create logged-in user in a different organization
      logged_in_person = create(:person)
      other_organization = create(:organization, :company)
      logged_in_teammate = create(:teammate, person: logged_in_person, organization: other_organization)
      create(:employment_tenure, teammate: logged_in_teammate, company: other_organization, started_at: 1.year.ago)
      
      # Person being viewed is in a different organization
      person_organization = create(:organization, :company)
      person_teammate = create(:teammate, person: person, organization: person_organization)
      create(:employment_tenure, teammate: person_teammate, company: person_organization, started_at: 1.year.ago)
      
      # Sign in
      sign_in_as_teammate_for_request(logged_in_person, other_organization)
      
      get public_person_path(person)
      expect(response).to have_http_status(:success)
      expect(response.body).not_to include('View Teammate Profile')
    end
  end
end

