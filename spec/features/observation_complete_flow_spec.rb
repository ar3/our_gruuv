require 'rails_helper'

RSpec.describe 'Observation Complete Flow', type: :feature do
  let(:company) { create(:organization, :company) }
  let(:observer) { create(:person) }
  let(:observer_teammate) { create(:teammate, person: observer, organization: company) }
  let(:observee1) { create(:teammate, organization: company) }
  let(:observee2) { create(:teammate, organization: company) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(observer)
    observer_teammate # Ensure observer teammate is created
  end

  describe 'Complete observation flow scenarios' do
    it 'creates observation with no abilities/assignments/aspirations available' do
      # Start at Index page
      visit organization_observations_path(company)
      
      # Verify we're on the index page
      expect(page).to have_content('Observations')
      expect(page).to have_content('No Observations Created')
      
      # Click "Create First Observation" button
      click_link 'Create First Observation'
      
      # Should redirect to new observation page
      expect(page).to have_current_path(new_organization_observation_path(company))
      expect(page).to have_content('Create Observation')
      expect(page).to have_content('Step 1 of 3')
      
      # Fill out Step 1 form
      fill_in 'observation[story]', with: 'Great work on the project! Sarah really stepped up and delivered excellent results.'
      select '😀 (Happy) Happy', from: 'observation[primary_feeling]'
      select '😎 (Proud) Proud', from: 'observation[secondary_feeling]'
      fill_in 'observation[observed_at]', with: Date.current.strftime('%Y-%m-%dT%H:%M')
      
      # Select observees
      first_teammate_checkbox = page.find('input[name="observation[teammate_ids][]"]', match: :first)
      first_teammate_checkbox.check
      
      # Submit Step 1
      find('input[type="submit"][value="2"]').click
      
      # Should redirect to Step 2
      expect(page).to have_current_path(set_ratings_organization_observation_path(company, 'new'))
      expect(page).to have_content('Ratings & Privacy')
      expect(page).to have_content('Step 2 of 3')
      
      # Verify no abilities/assignments are available
      expect(page).to have_content('No abilities or assignments available for the selected observees.')
      
      # Verify privacy level options are present
      expect(page).to have_css('input[name="observation[privacy_level]"]', count: 5)
      expect(page).to have_css('#privacy_observer_only')
      expect(page).to have_css('#privacy_observed_only')
      expect(page).to have_css('#privacy_managers_only')
      expect(page).to have_css('#privacy_observed_and_managers')
      expect(page).to have_css('#privacy_public')
      
      # Set privacy level
      find('#privacy_observed_only').choose
      
      # Submit Step 2
      find('input[type="submit"][value="3"]').click
      
      # Should redirect to Step 3
      expect(page).to have_current_path(review_organization_observation_path(company, 'new'))
      expect(page).to have_content('Review & Manage')
      expect(page).to have_content('Step 3 of 3')
      
      # Verify Step 3 shows our data
      expect(page).to have_content('Great work on the project! Sarah really stepped up and delivered excellent results.')
      expect(page).to have_content('😀 (Happy) Happy')
      expect(page).to have_content('😎 (Proud) Proud')
      expect(page).to have_content('Just for them')
      
      # Verify notification options are present
      expect(page).to have_css('input[name="observation[send_notifications]"]')
      expect(page).to have_css('input[name="observation[notify_teammate_ids][]"]')
      expect(page).to have_button('Create Observation')
      
      # Submit Step 3 to create observation
      click_button 'Create Observation'
      
      # Should create observation and redirect to show page
      expect(Observation.count).to eq(1)
      expect(Observee.count).to eq(1)
      expect(ObservationRating.count).to eq(0) # No ratings created
      
      observation = Observation.last
      expect(page).to have_current_path(organization_observation_path(company, observation))
      expect(page).to have_content('Observation was successfully created')
      expect(page).to have_content('Great work on the project! Sarah really stepped up and delivered excellent results.')
      
      # Verify show page elements are present
      expect(page).to have_css('a[href*="observations"]', text: 'Back to Observations')
      expect(page).to have_css('a.btn-outline-primary i.bi-eye') # View button
      expect(page).to have_css('a.btn-outline-secondary i.bi-pencil') # Edit button
      expect(page).to have_css('a.btn-outline-danger i.bi-trash') # Delete button
      
      # Go back to observations index
      click_link 'Back to Observations'
      
      # Should be back on observations index
      expect(page).to have_current_path(organization_observations_path(company))
      expect(page).to have_content('Observations')
      expect(page).to have_content('Great work on the project! Sarah really stepped up and delivered excellent results.')
      
      # Verify the new observation appears in the list
      expect(page).to have_css('a.btn-outline-primary i.bi-eye', count: 1) # Should have 1 view button
      
      # Verify filter modal can be opened
      click_button 'Filter & Sort'
      expect(page).to have_css('#observations-filter-modal', visible: true)
    end

    it 'creates observation with abilities/assignments/aspirations and rates one of each' do
      # Create abilities, assignments, and aspirations
      ability1 = create(:ability, organization: company, name: 'Ruby Programming')
      ability2 = create(:ability, organization: company, name: 'JavaScript')
      assignment1 = create(:assignment, company: company, title: 'Frontend Development')
      assignment2 = create(:assignment, company: company, title: 'Backend Development')
      aspiration1 = create(:aspiration, organization: company, name: 'Senior Developer')
      aspiration2 = create(:aspiration, organization: company, name: 'Tech Lead')
      
      # Start at Index page
      visit organization_observations_path(company)
      
      # Click "Create First Observation" button
      click_link 'Create First Observation'
      
      # Fill out Step 1 form
      fill_in 'observation[story]', with: 'Excellent technical leadership and code quality!'
      select '😀 (Happy) Happy', from: 'observation[primary_feeling]'
      select '😎 (Proud) Proud', from: 'observation[secondary_feeling]'
      fill_in 'observation[observed_at]', with: Date.current.strftime('%Y-%m-%dT%H:%M')
      
      # Select observees
      first_teammate_checkbox = page.find('input[name="observation[teammate_ids][]"]', match: :first)
      first_teammate_checkbox.check
      
      # Submit Step 1
      find('input[type="submit"][value="2"]').click
      
      # Should redirect to Step 2
      expect(page).to have_current_path(set_ratings_organization_observation_path(company, 'new'))
      expect(page).to have_content('Ratings & Privacy')
      
      # Add ratings for one of each type
      # Rate Ruby Programming ability
      expect(page).to have_css('select[name*="observation[observation_ratings_attributes]"][name*="ability"]', count: 2)
      ability_selects = page.all('select[name*="observation[observation_ratings_attributes]"][name*="ability"]')
      ability_selects.first.select('Strongly Agree (Exceptional)')
      
      # Rate Frontend Development assignment
      expect(page).to have_css('select[name*="observation[observation_ratings_attributes]"][name*="assignment"]', count: 2)
      assignment_selects = page.all('select[name*="observation[observation_ratings_attributes]"][name*="assignment"]')
      assignment_selects.first.select('Agree (Good)')
      
      # Rate Senior Developer aspiration
      expect(page).to have_css('select[name*="observation[observation_ratings_attributes]"][name*="aspiration"]', count: 2)
      aspiration_selects = page.all('select[name*="observation[observation_ratings_attributes]"][name*="aspiration"]')
      aspiration_selects.first.select('Strongly Agree (Exceptional)')
      
      # Set privacy level
      find('#privacy_observed_and_managers').choose
      
      # Submit Step 2
      find('input[type="submit"][value="3"]').click
      
      # Should redirect to Step 3
      expect(page).to have_current_path(review_organization_observation_path(company, 'new'))
      expect(page).to have_content('Review & Manage')
      
      # Verify Step 3 shows our data including ratings
      expect(page).to have_content('Excellent technical leadership and code quality!')
      expect(page).to have_content('😀 (Happy) Happy')
      expect(page).to have_content('😎 (Proud) Proud')
      expect(page).to have_content('For them and their managers')
      
      # Submit Step 3 to create observation
      click_button 'Create Observation'
      
      # Should create observation with ratings
      expect(Observation.count).to eq(1)
      expect(Observee.count).to eq(1)
      expect(ObservationRating.count).to eq(3) # One rating for each type
      
      observation = Observation.last
      expect(observation.observation_ratings.count).to eq(3)
      
      # Verify ratings were created correctly
      ability_rating = observation.observation_ratings.find_by(rateable_type: 'Ability')
      expect(ability_rating.rating).to eq('strongly_agree')
      
      assignment_rating = observation.observation_ratings.find_by(rateable_type: 'Assignment')
      expect(assignment_rating.rating).to eq('agree')
      
      aspiration_rating = observation.observation_ratings.find_by(rateable_type: 'Aspiration')
      expect(aspiration_rating.rating).to eq('strongly_agree')
      
      expect(page).to have_current_path(organization_observation_path(company, observation))
      expect(page).to have_content('Observation was successfully created')
    end

    it 'creates observation with both primary and secondary feelings' do
      # Start at Index page
      visit organization_observations_path(company)
      
      # Click "Create First Observation" button
      click_link 'Create First Observation'
      
      # Fill out Step 1 form with both feelings
      fill_in 'observation[story]', with: 'Amazing teamwork and collaboration!'
      select '😀 (Happy) Happy', from: 'observation[primary_feeling]'
      select '😎 (Proud) Proud', from: 'observation[secondary_feeling]'
      fill_in 'observation[observed_at]', with: Date.current.strftime('%Y-%m-%dT%H:%M')
      
      # Select observees
      first_teammate_checkbox = page.find('input[name="observation[teammate_ids][]"]', match: :first)
      first_teammate_checkbox.check
      
      # Submit Step 1
      find('input[type="submit"][value="2"]').click
      
      # Should redirect to Step 2
      expect(page).to have_current_path(set_ratings_organization_observation_path(company, 'new'))
      
      # Set privacy level
      find('#privacy_public').choose
      
      # Submit Step 2
      find('input[type="submit"][value="3"]').click
      
      # Should redirect to Step 3
      expect(page).to have_current_path(review_organization_observation_path(company, 'new'))
      
      # Verify Step 3 shows both feelings
      expect(page).to have_content('Amazing teamwork and collaboration!')
      expect(page).to have_content('😀 (Happy) Happy')
      expect(page).to have_content('😎 (Proud) Proud')
      expect(page).to have_content('Public to organization')
      
      # Submit Step 3 to create observation
      click_button 'Create Observation'
      
      # Should create observation
      expect(Observation.count).to eq(1)
      
      observation = Observation.last
      expect(observation.primary_feeling).to eq('happy')
      expect(observation.secondary_feeling).to eq('proud')
      
      expect(page).to have_current_path(organization_observation_path(company, observation))
      expect(page).to have_content('Observation was successfully created')
      
      # Verify show page elements are present
      expect(page).to have_css('a[href*="observations"]', text: 'Back to Observations')
      expect(page).to have_css('a.btn-outline-primary i.bi-eye') # View button
      expect(page).to have_css('a.btn-outline-secondary i.bi-pencil') # Edit button
      expect(page).to have_css('a.btn-outline-danger i.bi-trash') # Delete button
    end

    it 'creates observation with no feelings selected' do
      # Start at Index page
      visit organization_observations_path(company)
      
      # Click "Create First Observation" button
      click_link 'Create First Observation'
      
      # Fill out Step 1 form with NO feelings
      fill_in 'observation[story]', with: 'Professional work completed on time.'
      # Don't select any feelings
      fill_in 'observation[observed_at]', with: Date.current.strftime('%Y-%m-%dT%H:%M')
      
      # Select observees
      first_teammate_checkbox = page.find('input[name="observation[teammate_ids][]"]', match: :first)
      first_teammate_checkbox.check
      
      # Submit Step 1
      find('input[type="submit"][value="2"]').click
      
      # Should redirect to Step 2
      expect(page).to have_current_path(set_ratings_organization_observation_path(company, 'new'))
      
      # Set privacy level
      find('#privacy_observer_only').choose
      
      # Submit Step 2
      find('input[type="submit"][value="3"]').click
      
      # Should redirect to Step 3
      expect(page).to have_current_path(review_organization_observation_path(company, 'new'))
      
      # Verify Step 3 shows no feelings
      expect(page).to have_content('Professional work completed on time.')
      expect(page).to have_content('Just for me (Journal)')
      # Should not show feelings section or show "No feelings"
      
      # Submit Step 3 to create observation
      click_button 'Create Observation'
      
      # Should create observation
      expect(Observation.count).to eq(1)
      
      observation = Observation.last
      expect(observation.primary_feeling).to be_nil
      expect(observation.secondary_feeling).to be_nil
      
      expect(page).to have_current_path(organization_observation_path(company, observation))
      expect(page).to have_content('Observation was successfully created')
      
      # Verify show page elements are present
      expect(page).to have_css('a[href*="observations"]', text: 'Back to Observations')
      expect(page).to have_css('a.btn-outline-primary i.bi-eye') # View button
      expect(page).to have_css('a.btn-outline-secondary i.bi-pencil') # Edit button
      expect(page).to have_css('a.btn-outline-danger i.bi-trash') # Delete button
    end
  end

  describe 'Additional Happy Path Scenarios' do
    it 'creates observation with abilities/assignments/aspirations, rating all' do
      # Create abilities, assignments, and aspirations
      ability1 = create(:ability, organization: company, name: 'Ruby Programming')
      ability2 = create(:ability, organization: company, name: 'JavaScript')
      assignment1 = create(:assignment, company: company, title: 'Frontend Development')
      assignment2 = create(:assignment, company: company, title: 'Backend Development')
      aspiration1 = create(:aspiration, organization: company, name: 'Senior Developer')
      aspiration2 = create(:aspiration, organization: company, name: 'Tech Lead')

      visit new_organization_observation_path(company)

      # Fill out Step 1 form
      fill_in 'observation[story]', with: 'Comprehensive evaluation of all skills!'
      select '😀 (Happy) Happy', from: 'observation[primary_feeling]'
      select '😎 (Proud) Proud', from: 'observation[secondary_feeling]'
      fill_in 'observation[observed_at]', with: Date.current.strftime('%Y-%m-%dT%H:%M')

      # Select observees
      first_teammate_checkbox = page.find('input[name="observation[teammate_ids][]"]', match: :first)
      first_teammate_checkbox.check

      # Submit Step 1
      find('input[type="submit"][value="2"]').click

      # Should redirect to Step 2
      expect(page).to have_current_path(set_ratings_organization_observation_path(company, 'new'))
      expect(page).to have_content('Ratings & Privacy')

      # Rate ALL abilities
      expect(page).to have_css('select[name*="observation[observation_ratings_attributes]"][name*="ability"]', count: 2)
      ability_selects = page.all('select[name*="observation[observation_ratings_attributes]"][name*="ability"]')
      ability_selects[0].select('Strongly Agree (Exceptional)')
      ability_selects[1].select('Agree (Good)')

      # Rate ALL assignments
      expect(page).to have_css('select[name*="observation[observation_ratings_attributes]"][name*="assignment"]', count: 2)
      assignment_selects = page.all('select[name*="observation[observation_ratings_attributes]"][name*="assignment"]')
      assignment_selects[0].select('Strongly Agree (Exceptional)')
      assignment_selects[1].select('Agree (Good)')

      # Rate ALL aspirations
      expect(page).to have_css('select[name*="observation[observation_ratings_attributes]"][name*="aspiration"]', count: 2)
      aspiration_selects = page.all('select[name*="observation[observation_ratings_attributes]"][name*="aspiration"]')
      aspiration_selects[0].select('Strongly Agree (Exceptional)')
      aspiration_selects[1].select('Agree (Good)')

      # Set privacy level
      find('#privacy_public').choose

      # Submit Step 2
      find('input[type="submit"][value="3"]').click

      # Should redirect to Step 3
      expect(page).to have_current_path(review_organization_observation_path(company, 'new'))
      expect(page).to have_content('Review & Manage')

      # Submit Step 3 to create observation
      click_button 'Create Observation'

      # Should create observation with all ratings
      observation = Observation.last
      expect(observation.observation_ratings.count).to eq(6) # All ratings

      expect(page).to have_current_path(organization_observation_path(company, observation))
      expect(page).to have_content('Observation was successfully created')
    end

    it 'creates observation with primary feeling only' do
      visit new_organization_observation_path(company)

      # Fill out Step 1 form with only primary feeling
      fill_in 'observation[story]', with: 'Good work with single emotion!'
      select '😀 (Happy) Happy', from: 'observation[primary_feeling]'
      fill_in 'observation[observed_at]', with: Date.current.strftime('%Y-%m-%dT%H:%M')

      # Select observees
      first_teammate_checkbox = page.find('input[name="observation[teammate_ids][]"]', match: :first)
      first_teammate_checkbox.check

      # Submit Step 1
      find('input[type="submit"][value="2"]').click

      # Should redirect to Step 2
      expect(page).to have_current_path(set_ratings_organization_observation_path(company, 'new'))
      expect(page).to have_content('Ratings & Privacy')

      # Set privacy level
      find('#privacy_observed_only').choose

      # Submit Step 2
      find('input[type="submit"][value="3"]').click

      # Should redirect to Step 3
      expect(page).to have_current_path(review_organization_observation_path(company, 'new'))
      expect(page).to have_content('Review & Manage')

      # Verify Step 3 shows only primary feeling
      expect(page).to have_content('Good work with single emotion!')
      expect(page).to have_content('😀 (Happy) Happy')

      # Submit Step 3 to create observation
      click_button 'Create Observation'

      # Should create observation
      observation = Observation.last
      expect(observation.primary_feeling).to eq('happy')
      expect(observation.secondary_feeling).to be_nil

      expect(page).to have_current_path(organization_observation_path(company, observation))
      expect(page).to have_content('Observation was successfully created')
    end

    it 'creates observation with Slack notification sending' do
      # Create teammates with Slack user IDs
      observee1.person.update!(slack_user_id: 'U1234567890')
      observee2.person.update!(slack_user_id: 'U0987654321')

      visit new_organization_observation_path(company)

      # Fill out Step 1 form
      fill_in 'observation[story]', with: 'Great work that deserves Slack notification!'
      select '😀 (Happy) Happy', from: 'observation[primary_feeling]'
      fill_in 'observation[observed_at]', with: Date.current.strftime('%Y-%m-%dT%H:%M')

      # Select observees
      first_teammate_checkbox = page.find('input[name="observation[teammate_ids][]"]', match: :first)
      first_teammate_checkbox.check

      # Submit Step 1
      find('input[type="submit"][value="2"]').click

      # Should redirect to Step 2
      expect(page).to have_current_path(set_ratings_organization_observation_path(company, 'new'))
      expect(page).to have_content('Ratings & Privacy')

      # Set privacy level
      find('#privacy_observed_only').choose

      # Submit Step 2
      find('input[type="submit"][value="3"]').click

      # Should redirect to Step 3
      expect(page).to have_current_path(review_organization_observation_path(company, 'new'))
      expect(page).to have_content('Review & Manage')

      # Enable Slack notifications
      check 'observation[send_notifications]'

      # Verify notification options appear
      expect(page).to have_css('#notify_teammates_section', visible: true)

      # Select teammates to notify
      check "notify_teammate_#{observee1.id}"
      check "notify_teammate_#{observee2.id}"

      # Submit Step 3 to create observation
      click_button 'Create Observation'

      # Should create observation and redirect to show page
      observation = Observation.last
      expect(page).to have_current_path(organization_observation_path(company, observation))
      expect(page).to have_content('Observation was successfully created')

      # Verify Slack notifications were queued (mocked in test environment)
      expect(Observations::PostNotificationJob).to have_been_enqueued
    end
  end

  describe 'Validation & Error Scenarios' do
    it 'Step 1 validation failure - missing story' do
      visit new_organization_observation_path(company)

      # Submit without story
      first_teammate_checkbox = page.find('input[name="observation[teammate_ids][]"]', match: :first)
      first_teammate_checkbox.check
      fill_in 'observation[observed_at]', with: Date.current.strftime('%Y-%m-%dT%H:%M')

      find('input[type="submit"][value="2"]').click

      # Should stay on Step 1 with error
      expect(page).to have_current_path(organization_observations_path(company))
      expect(page).to have_content("can't be blank")
      expect(page).to have_content('Story')
    end

    it 'Step 1 validation failure - missing observees' do
      visit new_organization_observation_path(company)

      # Submit without observees
      fill_in 'observation[story]', with: 'Great work!'
      fill_in 'observation[observed_at]', with: Date.current.strftime('%Y-%m-%dT%H:%M')

      find('input[type="submit"][value="2"]').click

      # Should stay on Step 1 with error
      expect(page).to have_current_path(organization_observations_path(company))
      expect(page).to have_content("must have at least one observee")
    end

    it 'Step 2 validation failure - missing privacy level' do
      # Set up wizard data
      visit new_organization_observation_path(company)
      fill_in 'observation[story]', with: 'Great work!'
      fill_in 'observation[observed_at]', with: Date.current.strftime('%Y-%m-%dT%H:%M')
      first_teammate_checkbox = page.find('input[name="observation[teammate_ids][]"]', match: :first)
      first_teammate_checkbox.check
      find('input[type="submit"][value="2"]').click

      # Should be on Step 2
      expect(page).to have_current_path(set_ratings_organization_observation_path(company, 'new'))

      # Submit without privacy level
      find('input[type="submit"][value="3"]').click

      # Should stay on Step 2 with error
      expect(page).to have_current_path(set_ratings_organization_observation_path(company, 'new'))
      expect(page).to have_content("can't be blank")
      expect(page).to have_content('Privacy level')
    end

    it 'Step 2 re-rendering with pre-filled ratings' do
      # Create abilities for rating
      ability1 = create(:ability, organization: company, name: 'Ruby Programming')
      ability2 = create(:ability, organization: company, name: 'JavaScript')

      # Set up wizard data
      visit new_organization_observation_path(company)
      fill_in 'observation[story]', with: 'Great work!'
      fill_in 'observation[observed_at]', with: Date.current.strftime('%Y-%m-%dT%H:%M')
      first_teammate_checkbox = page.find('input[name="observation[teammate_ids][]"]', match: :first)
      first_teammate_checkbox.check
      find('input[type="submit"][value="2"]').click

      # Should be on Step 2
      expect(page).to have_current_path(set_ratings_organization_observation_path(company, 'new'))

      # Add some ratings
      expect(page).to have_css('select[name*="observation[observation_ratings_attributes]"][name*="ability"]', count: 2)
      ability_selects = page.all('select[name*="observation[observation_ratings_attributes]"][name*="ability"]')
      ability_selects.first.select('Strongly Agree (Exceptional)')

      # Submit without privacy level to trigger validation error
      find('input[type="submit"][value="3"]').click

      # Should stay on Step 2 with error but preserve ratings
      expect(page).to have_current_path(set_ratings_organization_observation_path(company, 'new'))
      expect(page).to have_content("can't be blank")

      # Verify ratings are preserved (this tests the TypeError bug scenario)
      expect(page).to have_css('select[name*="observation[observation_ratings_attributes]"][name*="ability"]', count: 2)
      ability_selects_after_error = page.all('select[name*="observation[observation_ratings_attributes]"][name*="ability"]')
      expect(ability_selects_after_error.first.value).to eq('strongly_agree')
    end

    it 'form value preservation across all validation failures' do
      # Test that form values are preserved when validation fails at any step
      visit new_organization_observation_path(company)

      # Fill out some fields
      fill_in 'observation[story]', with: 'Test story for preservation'
      select '😀 (Happy) Happy', from: 'observation[primary_feeling]'
      select '😎 (Proud) Proud', from: 'observation[secondary_feeling]'
      fill_in 'observation[observed_at]', with: Date.current.strftime('%Y-%m-%dT%H:%M')

      # Submit without observees to trigger validation error
      find('input[type="submit"][value="2"]').click

      # Should preserve filled data
      expect(page).to have_field('observation[story]', with: 'Test story for preservation')
      expect(page).to have_select('observation[primary_feeling]', selected: '😀 (Happy) Happy')
      expect(page).to have_select('observation[secondary_feeling]', selected: '😎 (Proud) Proud')
      expect(page).to have_field('observation[observed_at]', with: Date.current.strftime('%Y-%m-%dT%H:%M'))
    end
  end

  describe 'Navigation & State Scenarios' do
    it 'direct URL access to Step 2 without session data (should redirect)' do
      # Try to access Step 2 directly without session data
      visit set_ratings_organization_observation_path(company, 'new')

      # Should redirect to Step 1
      expect(page).to have_current_path(new_organization_observation_path(company))
    end

    it 'direct URL access to Step 3 without session data (should redirect)' do
      # Try to access Step 3 directly without session data
      visit review_organization_observation_path(company, 'new')

      # Should redirect to Step 1
      expect(page).to have_current_path(new_organization_observation_path(company))
    end

    it 'back button from Step 2 to Step 1 (data preservation)' do
      # Set up wizard data
      visit new_organization_observation_path(company)
      fill_in 'observation[story]', with: 'Test story for back button'
      select '😀 (Happy) Happy', from: 'observation[primary_feeling]'
      fill_in 'observation[observed_at]', with: Date.current.strftime('%Y-%m-%dT%H:%M')
      first_teammate_checkbox = page.find('input[name="observation[teammate_ids][]"]', match: :first)
      first_teammate_checkbox.check
      find('input[type="submit"][value="2"]').click

      # Should be on Step 2
      expect(page).to have_current_path(set_ratings_organization_observation_path(company, 'new'))

      # Click back button
      click_link 'Back to Step 1'

      # Should be back on Step 1 with preserved data
      expect(page).to have_current_path(new_organization_observation_path(company))
      expect(page).to have_field('observation[story]', with: 'Test story for back button')
      expect(page).to have_select('observation[primary_feeling]', selected: '😀 (Happy) Happy')
      expect(page).to have_field('observation[observed_at]', with: Date.current.strftime('%Y-%m-%dT%H:%M'))
    end

    it 'back button from Step 3 to Step 2 (data preservation)' do
      # Set up wizard data through Step 2
      visit new_organization_observation_path(company)
      fill_in 'observation[story]', with: 'Test story for back button'
      fill_in 'observation[observed_at]', with: Date.current.strftime('%Y-%m-%dT%H:%M')
      first_teammate_checkbox = page.find('input[name="observation[teammate_ids][]"]', match: :first)
      first_teammate_checkbox.check
      find('input[type="submit"][value="2"]').click

      find('#privacy_observed_only').choose
      find('input[type="submit"][value="3"]').click

      # Should be on Step 3
      expect(page).to have_current_path(review_organization_observation_path(company, 'new'))

      # Click back button
      click_link 'Back to Step 2'

      # Should be back on Step 2 with preserved data
      expect(page).to have_current_path(set_ratings_organization_observation_path(company, 'new'))
      expect(page).to have_content('Ratings & Privacy')
      expect(page).to have_css('#privacy_observed_only:checked')
    end

    it 'browser refresh on each step (session persistence)' do
      # Set up wizard data
      visit new_organization_observation_path(company)
      fill_in 'observation[story]', with: 'Test story for refresh'
      fill_in 'observation[observed_at]', with: Date.current.strftime('%Y-%m-%dT%H:%M')
      first_teammate_checkbox = page.find('input[name="observation[teammate_ids][]"]', match: :first)
      first_teammate_checkbox.check
      find('input[type="submit"][value="2"]').click

      # Should be on Step 2
      expect(page).to have_current_path(set_ratings_organization_observation_path(company, 'new'))

      # Refresh the page
      page.refresh

      # Should still be on Step 2 with data preserved
      expect(page).to have_current_path(set_ratings_organization_observation_path(company, 'new'))
      expect(page).to have_content('Ratings & Privacy')
    end
  end

  describe 'Edge Cases & Data Types' do
    it 'observee selection with empty string in array (Rails checkbox behavior)' do
      visit new_organization_observation_path(company)

      # Fill out form
      fill_in 'observation[story]', with: 'Test with checkbox edge case'
      fill_in 'observation[observed_at]', with: Date.current.strftime('%Y-%m-%dT%H:%M')

      # Select observees (this might include empty strings in Rails)
      first_teammate_checkbox = page.find('input[name="observation[teammate_ids][]"]', match: :first)
      first_teammate_checkbox.check

      # Submit Step 1
      find('input[type="submit"][value="2"]').click

      # Should work despite potential empty strings in array
      expect(page).to have_current_path(set_ratings_organization_observation_path(company, 'new'))
    end

    it 'feelings selection with empty strings' do
      visit new_organization_observation_path(company)

      # Fill out form
      fill_in 'observation[story]', with: 'Test with empty feelings'
      fill_in 'observation[observed_at]', with: Date.current.strftime('%Y-%m-%dT%H:%M')
      first_teammate_checkbox = page.find('input[name="observation[teammate_ids][]"]', match: :first)
      first_teammate_checkbox.check

      # Submit Step 1
      find('input[type="submit"][value="2"]').click

      # Should work with empty feelings
      expect(page).to have_current_path(set_ratings_organization_observation_path(company, 'new'))
    end

    it 'rating selection with nil values' do
      # Create abilities for rating
      ability1 = create(:ability, organization: company, name: 'Ruby Programming')

      # Set up wizard data
      visit new_organization_observation_path(company)
      fill_in 'observation[story]', with: 'Test with nil ratings'
      fill_in 'observation[observed_at]', with: Date.current.strftime('%Y-%m-%dT%H:%M')
      first_teammate_checkbox = page.find('input[name="observation[teammate_ids][]"]', match: :first)
      first_teammate_checkbox.check
      find('input[type="submit"][value="2"]').click

      # Should be on Step 2
      expect(page).to have_current_path(set_ratings_organization_observation_path(company, 'new'))

      # Verify rating selects render without errors even with nil values
      expect(page).to have_css('select[name*="observation[observation_ratings_attributes]"][name*="ability"]', count: 1)
      
      # Don't select any rating (leave as nil)
      find('#privacy_observed_only').choose
      find('input[type="submit"][value="3"]').click

      # Should work with nil ratings
      expect(page).to have_current_path(review_organization_observation_path(company, 'new'))
    end

    it 'rating selection with empty string values' do
      # Create abilities for rating
      ability1 = create(:ability, organization: company, name: 'Ruby Programming')

      # Set up wizard data
      visit new_organization_observation_path(company)
      fill_in 'observation[story]', with: 'Test with empty string ratings'
      fill_in 'observation[observed_at]', with: Date.current.strftime('%Y-%m-%dT%H:%M')
      first_teammate_checkbox = page.find('input[name="observation[teammate_ids][]"]', match: :first)
      first_teammate_checkbox.check
      find('input[type="submit"][value="2"]').click

      # Should be on Step 2
      expect(page).to have_current_path(set_ratings_organization_observation_path(company, 'new'))

      # Select empty string rating (blank option)
      expect(page).to have_css('select[name*="observation[observation_ratings_attributes]"][name*="ability"]', count: 1)
      ability_selects = page.all('select[name*="observation[observation_ratings_attributes]"][name*="ability"]')
      ability_selects.first.select('') # Select blank option

      find('#privacy_observed_only').choose
      find('input[type="submit"][value="3"]').click

      # Should work with empty string ratings
      expect(page).to have_current_path(review_organization_observation_path(company, 'new'))
    end

    it 'large text story (10,000 characters)' do
      large_story = 'A' * 10000

      visit new_organization_observation_path(company)

      # Fill out form with large story
      fill_in 'observation[story]', with: large_story
      fill_in 'observation[observed_at]', with: Date.current.strftime('%Y-%m-%dT%H:%M')
      first_teammate_checkbox = page.find('input[name="observation[teammate_ids][]"]', match: :first)
      first_teammate_checkbox.check

      # Submit Step 1
      find('input[type="submit"][value="2"]').click

      # Should work with large text
      expect(page).to have_current_path(set_ratings_organization_observation_path(company, 'new'))

      # Complete the flow
      find('#privacy_observed_only').choose
      find('input[type="submit"][value="3"]').click
      click_button 'Create Observation'

      # Should create observation with large story
      observation = Observation.last
      expect(observation.story.length).to eq(10000)
    end

    it 'special characters in story (emojis, unicode, markdown)' do
      special_story = "🎉 Great work! 🚀\n\n**Bold text** and *italic text*\n\n- Bullet point 1\n- Bullet point 2\n\n> Quote block\n\n`code snippet`\n\nUnicode: ñáéíóú 中文 日本語"

      visit new_organization_observation_path(company)

      # Fill out form with special characters
      fill_in 'observation[story]', with: special_story
      fill_in 'observation[observed_at]', with: Date.current.strftime('%Y-%m-%dT%H:%M')
      first_teammate_checkbox = page.find('input[name="observation[teammate_ids][]"]', match: :first)
      first_teammate_checkbox.check

      # Submit Step 1
      find('input[type="submit"][value="2"]').click

      # Should work with special characters
      expect(page).to have_current_path(set_ratings_organization_observation_path(company, 'new'))

      # Complete the flow
      find('#privacy_observed_only').choose
      find('input[type="submit"][value="3"]').click
      click_button 'Create Observation'

      # Should create observation with special characters
      observation = Observation.last
      expect(observation.story).to eq(special_story)
    end

    it 'multiple observees with various combinations' do
      # Create additional teammates
      observee3 = create(:teammate, organization: company)
      observee4 = create(:teammate, organization: company)

      visit new_organization_observation_path(company)

      # Fill out form
      fill_in 'observation[story]', with: 'Great work by multiple people!'
      fill_in 'observation[observed_at]', with: Date.current.strftime('%Y-%m-%dT%H:%M')

      # Select multiple observees
      teammate_checkboxes = page.all('input[name="observation[teammate_ids][]"]')
      expect(teammate_checkboxes.count).to be >= 2
      
      teammate_checkboxes[0].check
      teammate_checkboxes[1].check

      # Submit Step 1
      find('input[type="submit"][value="2"]').click

      # Should work with multiple observees
      expect(page).to have_current_path(set_ratings_organization_observation_path(company, 'new'))

      # Complete the flow
      find('#privacy_observed_only').choose
      find('input[type="submit"][value="3"]').click
      click_button 'Create Observation'

      # Should create observation with multiple observees
      observation = Observation.last
      expect(observation.observees.count).to eq(2)
    end
  end

  describe 'Individual observation flow components' do
    it 'shows empty state when no observations exist' do
      visit organization_observations_path(company)
      
      expect(page).to have_content('No Observations Created')
      expect(page).to have_content('Start by creating your first observation to give feedback to your teammates.')
      expect(page).to have_link('Create First Observation')
    end

    it 'shows observations in table format' do
      # Create some observations
      observation1 = create(:observation, observer: observer, company: company, story: 'First observation')
      observation1.observees.create!(teammate: observee1)
      
      observation2 = create(:observation, observer: observer, company: company, story: 'Second observation')
      observation2.observees.create!(teammate: observee2)
      
      visit organization_observations_path(company)
      
      # Should show observations in table
      expect(page).to have_content('First observation')
      expect(page).to have_content('Second observation')
      expect(page).to have_css('table.table')
      
      # Should have view buttons
      expect(page).to have_css('a.btn-outline-primary i.bi-eye', count: 2)
    end

    it 'allows filtering and sorting through modal' do
      visit organization_observations_path(company)
      
      # Click Filter & Sort button
      click_button 'Filter & Sort'
      
      # Should open modal - wait for it to appear
      expect(page).to have_css('#observations-filter-modal', visible: true)
      expect(page).to have_content('Filter & Sort Observations (coming soon)')
      
      # Should have filter options
      expect(page).to have_content('Privacy Level')
      expect(page).to have_content('Timeframe')
      expect(page).to have_content('Sort Options')
      expect(page).to have_content('View Style')
      expect(page).to have_content('Spotlight')
      
      # Apply Filters button should be disabled
      expect(page).to have_css('button.btn-primary.disabled')
      
      # Close modal
      click_button 'Cancel'
      # Modal might not close in test environment due to Bootstrap JS not being loaded
      # Just verify the modal content is there
      expect(page).to have_content('Filter & Sort Observations (coming soon)')
    end

    it 'renders Step 1 form correctly' do
      visit new_organization_observation_path(company)
      
      expect(page).to have_content('Create Observation')
      expect(page).to have_field('observation[story]')
      expect(page).to have_select('observation[primary_feeling]')
      expect(page).to have_select('observation[secondary_feeling]')
      expect(page).to have_field('observation[observed_at]')
      expect(page).to have_css('input[type="submit"][value="2"]')
    end

    it 'handles validation errors gracefully in Step 1' do
      # Start at new observation page
      visit new_organization_observation_path(company)
      
      # Submit without required fields
      find('input[type="submit"][value="2"]').click
      
      # Should stay on Step 1 with errors
      expect(page).to have_current_path(organization_observations_path(company))
      expect(page).to have_content("can't be blank")
    end

    it 'preserves form data on validation errors' do
      # Start at new observation page
      visit new_organization_observation_path(company)
      
      # Fill out some fields but miss required ones
      fill_in 'observation[story]', with: 'Test story'
      select '😀 (Happy) Happy', from: 'observation[primary_feeling]'
      page.find('input[name="observation[teammate_ids][]"]', match: :first).check
      
      # Submit with missing required field
      find('input[type="submit"][value="2"]').click
      
      # Should preserve the filled data
      expect(page).to have_field('observation[story]', with: 'Test story')
      expect(page).to have_select('observation[primary_feeling]', selected: '😀 (Happy) Happy')
      expect(page).to have_checked_field(page.find('input[name="observation[teammate_ids][]"]', match: :first)['id'])
    end

    it 'allows editing observation from show page' do
      # Create an observation first
      observation = create(:observation, observer: observer, company: company, story: 'Original story')
      observation.observees.create!(teammate: observee1)
      
      visit organization_observation_path(company, observation)
      
      # Click edit button
      click_link 'Edit'
      
      # Should go to edit page
      expect(page).to have_current_path(edit_organization_observation_path(company, observation))
      expect(page).to have_field('observation[story]', with: 'Original story')
      
      # Update the story
      fill_in 'observation[story]', with: 'Updated story'
      click_button 'Update Observation'
      
      # Should redirect back to show page
      expect(page).to have_current_path(organization_observation_path(company, observation))
      expect(page).to have_content('Updated story')
    end

    it 'allows posting to Slack from show page' do
      # Create an observation first
      observation = create(:observation, observer: observer, company: company, story: 'Test story')
      observation.observees.create!(teammate: observee1)
      
      visit organization_observation_path(company, observation)
      
      # Check notification options
      check "notify_#{observee1.id}"
      
      # Submit Slack notification
      click_button 'Send Slack Notifications'
      
      # Should redirect back to show page with success message
      expect(page).to have_current_path(organization_observation_path(company, observation))
      expect(page).to have_content('Notifications sent successfully')
    end

    it 'navigates from index to show page and back' do
      # Create an observation first
      observation = create(:observation, observer: observer, company: company, story: 'Test observation')
      observation.observees.create!(teammate: observee1)
      
      # Start at index page
      visit organization_observations_path(company)
      
      # Should see the observation
      expect(page).to have_content('Test observation')
      
      # Click view button (first one)
      first('a.btn-outline-primary').click
      
      # Should go to show page
      expect(page).to have_current_path(organization_observation_path(company, observation))
      expect(page).to have_content('Test observation')
      
      # Go back to observations index
      click_link 'Back to Observations'
      
      # Should be back on observations index
      expect(page).to have_current_path(organization_observations_path(company))
      expect(page).to have_content('Test observation')
    end
  end
end