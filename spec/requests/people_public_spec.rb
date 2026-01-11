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
      
      # Create a milestone with public_profile_published_at (factory will create certified_by automatically)
      ability = create(:ability, organization: organization)
      create(:teammate_milestone,
        teammate: teammate,
        ability: ability,
        milestone_level: 3,
        attained_at: 1.month.ago,
        public_profile_published_at: 1.week.ago
      )
      
      # Reload person to ensure associations are fresh
      person.reload
      
      get public_person_path(person)
      expect(response).to have_http_status(:success)
      # Just verify it renders without nil errors - the main goal
      expect(response.body).to include('John D.')
    end

    it 'only shows milestones with public_profile_published_at' do
      organization = create(:organization, :company)
      teammate = create(:teammate, person: person, organization: organization)
      ability = create(:ability, organization: organization)
      
      # Create a milestone with public_profile_published_at
      published_milestone = create(:teammate_milestone,
        teammate: teammate,
        ability: ability,
        milestone_level: 3,
        attained_at: 1.month.ago,
        public_profile_published_at: 1.week.ago
      )
      
      # Create a milestone without public_profile_published_at
      unpublished_milestone = create(:teammate_milestone,
        teammate: teammate,
        ability: ability,
        milestone_level: 2,
        attained_at: 2.months.ago,
        public_profile_published_at: nil
      )
      
      get public_person_path(person)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Milestone #{published_milestone.milestone_level}")
      expect(response.body).not_to include("Milestone #{unpublished_milestone.milestone_level}")
    end

    it 'shows profile image from person_identity when available' do
      create(:person_identity, person: person, profile_image_url: 'https://example.com/person-image.jpg')
      
      get public_person_path(person)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('person-image.jpg')
      expect(response.body).not_to include('bi-person-badge')
    end

    it 'shows profile image from teammate_identity when available' do
      organization = create(:organization, :company)
      teammate = create(:teammate, person: person, organization: organization)
      create(:teammate_identity, teammate: teammate, profile_image_url: 'https://example.com/teammate-image.jpg')
      
      get public_person_path(person)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('teammate-image.jpg')
      expect(response.body).not_to include('bi-person-badge')
    end

    it 'shows latest profile image when multiple identities have images' do
      # Create an older person_identity
      old_identity = create(:person_identity, person: person, profile_image_url: 'https://example.com/old-image.jpg')
      old_identity.update_column(:updated_at, 2.days.ago)
      
      # Create a newer teammate_identity
      organization = create(:organization, :company)
      teammate = create(:teammate, person: person, organization: organization)
      new_identity = create(:teammate_identity, teammate: teammate, profile_image_url: 'https://example.com/new-image.jpg')
      new_identity.update_column(:updated_at, 1.day.ago)
      
      get public_person_path(person)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('new-image.jpg')
      expect(response.body).not_to include('old-image.jpg')
    end

    it 'shows icon when no profile images are available' do
      get public_person_path(person)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('bi-person-badge')
    end

    it 'shows all world-public observations across organizations' do
      org1 = create(:organization, :company)
      org2 = create(:organization, :company)
      teammate1 = create(:teammate, person: person, organization: org1)
      teammate2 = create(:teammate, person: person, organization: org2)
      
      observer1 = create(:person)
      observer2 = create(:person)
      
      # Create world-public observation in org1
      obs1 = create(:observation,
        observer: observer1,
        company: org1,
        privacy_level: 'public_to_world',
        published_at: 1.day.ago,
        observed_at: 1.day.ago
      )
      create(:observee, observation: obs1, teammate: teammate1)
      
      # Create world-public observation in org2
      obs2 = create(:observation,
        observer: observer2,
        company: org2,
        privacy_level: 'public_to_world',
        published_at: 2.days.ago,
        observed_at: 2.days.ago
      )
      create(:observee, observation: obs2, teammate: teammate2)
      
      # Create a non-world-public observation (should not appear)
      obs3 = create(:observation,
        observer: observer1,
        company: org1,
        privacy_level: 'public_to_company',
        published_at: 3.days.ago,
        observed_at: 3.days.ago
      )
      create(:observee, observation: obs3, teammate: teammate1)
      
      get public_person_path(person)
      expect(response).to have_http_status(:success)
      expect(response.body).to include(obs1.decorate.story_html)
      expect(response.body).to include(obs2.decorate.story_html)
      expect(response.body).not_to include(obs3.decorate.story_html)
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
      expect(response.body).to include(internal_organization_company_teammate_path(organization, person_teammate))
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

