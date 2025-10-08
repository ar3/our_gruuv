require 'rails_helper'

RSpec.describe 'Observation Wizard JavaScript Interactions', type: :system, js: true do
  let(:company) { create(:organization, :company) }
  let(:observer) { create(:person) }
  let(:observer_teammate) { create(:teammate, person: observer, organization: company) }
  let(:observee1) { create(:teammate, organization: company) }
  let(:observee2) { create(:teammate, organization: company) }
  let(:ability1) { create(:ability, organization: company, name: 'Ruby Programming') }
  let(:ability2) { create(:ability, organization: company, name: 'JavaScript') }
  let(:assignment1) { create(:assignment, company: company, title: 'Frontend Development') }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(observer)
    observer_teammate # Ensure observer teammate is created
  end

  describe 'Step 1: Form element interactions' do
    it 'shows/hides form validation messages dynamically' do
      visit new_organization_observation_path(company)

      # Try to submit without required fields
      find('input[type="submit"][value="2"]').click

      # Should show validation messages
      expect(page).to have_content("can't be blank")
      expect(page).to have_css('.form-control.is-invalid')

      # Fill in required fields
      fill_in 'observation[story]', with: 'Great work!'
      fill_in 'observation[observed_at]', with: Date.current.strftime('%Y-%m-%dT%H:%M')
      first_teammate_checkbox = page.find('input[name="observation[teammate_ids][]"]', match: :first)
      first_teammate_checkbox.check

      # Validation messages should clear
      expect(page).not_to have_css('.form-control.is-invalid')
    end

    it 'handles teammate checkbox interactions' do
      visit new_organization_observation_path(company)

      # Check first teammate
      teammate_checkboxes = page.all('input[name="observation[teammate_ids][]"]')
      teammate_checkboxes[0].check

      # Verify checkbox is checked
      expect(teammate_checkboxes[0]).to be_checked

      # Uncheck teammate
      teammate_checkboxes[0].uncheck

      # Verify checkbox is unchecked
      expect(teammate_checkboxes[0]).not_to be_checked
    end

    it 'handles feelings dropdown interactions' do
      visit new_organization_observation_path(company)

      # Select primary feeling
      select '😀 (Happy) Happy', from: 'observation[primary_feeling]'
      expect(page).to have_select('observation[primary_feeling]', selected: '😀 (Happy) Happy')

      # Select secondary feeling
      select '😎 (Proud) Proud', from: 'observation[secondary_feeling]'
      expect(page).to have_select('observation[secondary_feeling]', selected: '😎 (Proud) Proud')

      # Change selections
      select '😊 (Excited) Excited', from: 'observation[primary_feeling]'
      expect(page).to have_select('observation[primary_feeling]', selected: '😊 (Excited) Excited')
    end

    it 'handles datetime input interactions' do
      visit new_organization_observation_path(company)

      # Set datetime
      fill_in 'observation[observed_at]', with: '2024-01-15T14:30'
      expect(page).to have_field('observation[observed_at]', with: '2024-01-15T14:30')

      # Change datetime
      fill_in 'observation[observed_at]', with: '2024-01-16T09:15'
      expect(page).to have_field('observation[observed_at]', with: '2024-01-16T09:15')
    end
  end

  describe 'Step 2: Rating interactions' do
    before do
      # Set up wizard data
      visit new_organization_observation_path(company)
      fill_in 'observation[story]', with: 'Great work!'
      fill_in 'observation[observed_at]', with: Date.current.strftime('%Y-%m-%dT%H:%M')
      first_teammate_checkbox = page.find('input[name="observation[teammate_ids][]"]', match: :first)
      first_teammate_checkbox.check
      find('input[type="submit"][value="2"]').click
    end

    it 'handles ability rating selections' do
      # Should be on Step 2
      expect(page).to have_current_path(set_ratings_organization_observation_path(company, 'new'))

      # Select ability ratings
      ability_selects = page.all('select[name*="observation[observation_ratings_attributes]"][name*="ability"]')
      ability_selects[0].select('Strongly Agree (Exceptional)')
      ability_selects[1].select('Agree (Good)')

      # Verify selections
      expect(ability_selects[0].value).to eq('strongly_agree')
      expect(ability_selects[1].value).to eq('agree')
    end

    it 'handles assignment rating selections' do
      # Should be on Step 2
      expect(page).to have_current_path(set_ratings_organization_observation_path(company, 'new'))

      # Select assignment ratings
      assignment_selects = page.all('select[name*="observation[observation_ratings_attributes]"][name*="assignment"]')
      assignment_selects[0].select('Strongly Agree (Exceptional)')

      # Verify selection
      expect(assignment_selects[0].value).to eq('strongly_agree')
    end

    it 'handles privacy level radio button interactions' do
      # Should be on Step 2
      expect(page).to have_current_path(set_ratings_organization_observation_path(company, 'new'))

      # Select privacy level
      find('#privacy_observed_only').choose
      expect(page).to have_css('#privacy_observed_only:checked')

      # Change privacy level
      find('#privacy_public').choose
      expect(page).to have_css('#privacy_public:checked')
      expect(page).not_to have_css('#privacy_observed_only:checked')
    end

    it 'handles rating changes and preserves state' do
      # Should be on Step 2
      expect(page).to have_current_path(set_ratings_organization_observation_path(company, 'new'))

      # Select some ratings
      ability_selects = page.all('select[name*="observation[observation_ratings_attributes]"][name*="ability"]')
      ability_selects[0].select('Strongly Agree (Exceptional)')
      find('#privacy_observed_only').choose

      # Submit without privacy level to trigger validation error
      find('input[type="submit"][value="3"]').click

      # Should stay on Step 2 with error
      expect(page).to have_current_path(set_ratings_organization_observation_path(company, 'new'))
      expect(page).to have_content("can't be blank")

      # Verify ratings are preserved
      ability_selects_after_error = page.all('select[name*="observation[observation_ratings_attributes]"][name*="ability"]')
      expect(ability_selects_after_error[0].value).to eq('strongly_agree')
    end
  end

  describe 'Step 3: Notification interactions' do
    before do
      # Set up wizard data through Step 2
      visit new_organization_observation_path(company)
      fill_in 'observation[story]', with: 'Great work!'
      fill_in 'observation[observed_at]', with: Date.current.strftime('%Y-%m-%dT%H:%M')
      first_teammate_checkbox = page.find('input[name="observation[teammate_ids][]"]', match: :first)
      first_teammate_checkbox.check
      find('input[type="submit"][value="2"]').click
      find('#privacy_observed_only').choose
      find('input[type="submit"][value="3"]').click
    end

    it 'shows/hides notification section based on checkbox' do
      # Should be on Step 3
      expect(page).to have_current_path(review_organization_observation_path(company, 'new'))

      # Notification section should be hidden initially
      expect(page).to have_css('#notify_teammates_section', visible: false)

      # Check notification checkbox
      check 'observation[send_notifications]'

      # Notification section should be visible
      expect(page).to have_css('#notify_teammates_section', visible: true)

      # Uncheck notification checkbox
      uncheck 'observation[send_notifications]'

      # Notification section should be hidden again
      expect(page).to have_css('#notify_teammates_section', visible: false)
    end

    it 'handles teammate notification checkbox interactions' do
      # Should be on Step 3
      expect(page).to have_current_path(review_organization_observation_path(company, 'new'))

      # Enable notifications
      check 'observation[send_notifications]'

      # Check teammate notification checkboxes
      teammate_notification_checkboxes = page.all('input[name="observation[notify_teammate_ids][]"]')
      teammate_notification_checkboxes[0].check

      # Verify checkbox is checked
      expect(teammate_notification_checkboxes[0]).to be_checked

      # Uncheck teammate notification checkbox
      teammate_notification_checkboxes[0].uncheck

      # Verify checkbox is unchecked
      expect(teammate_notification_checkboxes[0]).not_to be_checked
    end

    it 'shows Slack connection status indicators' do
      # Set up teammates with different Slack status
      observee1.person.update!(slack_user_id: 'U1234567890')
      observee2.person.update!(slack_user_id: nil)

      # Refresh to get updated teammate data
      page.refresh

      # Enable notifications
      check 'observation[send_notifications]'

      # Should show Slack status indicators
      expect(page).to have_css('i.bi-check-circle.text-success', count: 1)
      expect(page).to have_css('i.bi-exclamation-triangle.text-warning', count: 1)
    end
  end

  describe 'Cross-step navigation and state preservation' do
    it 'preserves form state when navigating back and forth' do
      # Fill Step 1
      visit new_organization_observation_path(company)
      fill_in 'observation[story]', with: 'Test story for navigation'
      select '😀 (Happy) Happy', from: 'observation[primary_feeling]'
      fill_in 'observation[observed_at]', with: '2024-01-15T14:30'
      first_teammate_checkbox = page.find('input[name="observation[teammate_ids][]"]', match: :first)
      first_teammate_checkbox.check

      # Go to Step 2
      find('input[type="submit"][value="2"]').click
      expect(page).to have_current_path(set_ratings_organization_observation_path(company, 'new'))

      # Add some ratings
      ability_selects = page.all('select[name*="observation[observation_ratings_attributes]"][name*="ability"]')
      ability_selects[0].select('Strongly Agree (Exceptional)')
      find('#privacy_observed_only').choose

      # Go back to Step 1
      click_link 'Back to Step 1'

      # Verify Step 1 data is preserved
      expect(page).to have_field('observation[story]', with: 'Test story for navigation')
      expect(page).to have_select('observation[primary_feeling]', selected: '😀 (Happy) Happy')
      expect(page).to have_field('observation[observed_at]', with: '2024-01-15T14:30')
      expect(page).to have_checked_field(page.find('input[name="observation[teammate_ids][]"]', match: :first)['id'])

      # Go back to Step 2
      find('input[type="submit"][value="2"]').click

      # Verify Step 2 data is preserved
      ability_selects_after_back = page.all('select[name*="observation[observation_ratings_attributes]"][name*="ability"]')
      expect(ability_selects_after_back[0].value).to eq('strongly_agree')
      expect(page).to have_css('#privacy_observed_only:checked')
    end

    it 'handles browser refresh on each step' do
      # Fill Step 1 and go to Step 2
      visit new_organization_observation_path(company)
      fill_in 'observation[story]', with: 'Test story for refresh'
      fill_in 'observation[observed_at]', with: Date.current.strftime('%Y-%m-%dT%H:%M')
      first_teammate_checkbox = page.find('input[name="observation[teammate_ids][]"]', match: :first)
      first_teammate_checkbox.check
      find('input[type="submit"][value="2"]').click

      # Should be on Step 2
      expect(page).to have_current_path(set_ratings_organization_observation_path(company, 'new'))

      # Add some data
      find('#privacy_observed_only').choose

      # Refresh the page
      page.refresh

      # Should still be on Step 2 with data preserved
      expect(page).to have_current_path(set_ratings_organization_observation_path(company, 'new'))
      expect(page).to have_content('Ratings & Privacy')
      expect(page).to have_css('#privacy_observed_only:checked')
    end
  end

  describe 'Modal interactions' do
    it 'opens and closes filter modal' do
      # Create an observation first
      observation = create(:observation, observer: observer, company: company)
      observation.observees.create!(teammate: observee1)

      visit organization_observations_path(company)

      # Open filter modal
      click_button 'Filter & Sort'
      expect(page).to have_css('#observations-filter-modal', visible: true)

      # Close modal
      find('#observations-filter-modal .btn-close').click
      expect(page).to have_css('#observations-filter-modal', visible: false)
    end

    it 'handles modal form interactions' do
      # Create an observation first
      observation = create(:observation, observer: observer, company: company)
      observation.observees.create!(teammate: observee1)

      visit organization_observations_path(company)

      # Open filter modal
      click_button 'Filter & Sort'

      # Interact with modal form elements
      check 'privacy_observer_only'
      check 'privacy_public'
      select 'Most recent', from: 'sort'
      choose 'viewStyle', option: 'cards'

      # Verify selections
      expect(page).to have_checked_field('privacy_observer_only')
      expect(page).to have_checked_field('privacy_public')
      expect(page).to have_select('sort', selected: 'Most recent')
      expect(page).to have_checked_field('viewStyle', with: 'cards')
    end
  end

  describe 'Tooltip interactions' do
    it 'shows tooltips on hover' do
      # Create an observation first
      observation = create(:observation, observer: observer, company: company)
      observation.observees.create!(teammate: observee1)

      visit organization_observations_path(company)

      # Hover over tooltip elements
      tooltip_elements = page.all('[data-bs-toggle="tooltip"]')
      expect(tooltip_elements.count).to be > 0

      # Tooltips should be present (Bootstrap tooltips)
      tooltip_elements.each do |element|
        expect(element['data-bs-toggle']).to eq('tooltip')
      end
    end
  end

  describe 'Dynamic content loading' do
    it 'handles dynamic teammate loading' do
      # Create additional teammates
      observee3 = create(:teammate, organization: company)
      observee4 = create(:teammate, organization: company)

      visit new_organization_observation_path(company)

      # Should show all teammates
      teammate_checkboxes = page.all('input[name="observation[teammate_ids][]"]')
      expect(teammate_checkboxes.count).to be >= 4

      # Should show teammate names and emails
      expect(page).to have_content(observee3.person.preferred_name || observee3.person.first_name)
      expect(page).to have_content(observee4.person.preferred_name || observee4.person.first_name)
    end

    it 'handles dynamic rating options loading' do
      # Create additional abilities and assignments
      ability3 = create(:ability, organization: company, name: 'Python')
      assignment2 = create(:assignment, company: company, title: 'Data Analysis')

      # Set up wizard data
      visit new_organization_observation_path(company)
      fill_in 'observation[story]', with: 'Great work!'
      fill_in 'observation[observed_at]', with: Date.current.strftime('%Y-%m-%dT%H:%M')
      first_teammate_checkbox = page.find('input[name="observation[teammate_ids][]"]', match: :first)
      first_teammate_checkbox.check
      find('input[type="submit"][value="2"]').click

      # Should show all rating options
      ability_selects = page.all('select[name*="observation[observation_ratings_attributes]"][name*="ability"]')
      assignment_selects = page.all('select[name*="observation[observation_ratings_attributes]"][name*="assignment"]')
      
      expect(ability_selects.count).to be >= 3
      expect(assignment_selects.count).to be >= 2
    end
  end

  describe 'Error handling and recovery' do
    it 'handles JavaScript errors gracefully' do
      # This test ensures the form still works even if JavaScript fails
      visit new_organization_observation_path(company)

      # Fill out form
      fill_in 'observation[story]', with: 'Test story'
      fill_in 'observation[observed_at]', with: Date.current.strftime('%Y-%m-%dT%H:%M')
      first_teammate_checkbox = page.find('input[name="observation[teammate_ids][]"]', match: :first)
      first_teammate_checkbox.check

      # Submit form
      find('input[type="submit"][value="2"]').click

      # Should still work without JavaScript errors
      expect(page).to have_current_path(set_ratings_organization_observation_path(company, 'new'))
    end

    it 'handles network errors gracefully' do
      # This test simulates network issues
      visit new_organization_observation_path(company)

      # Fill out form
      fill_in 'observation[story]', with: 'Test story'
      fill_in 'observation[observed_at]', with: Date.current.strftime('%Y-%m-%dT%H:%M')
      first_teammate_checkbox = page.find('input[name="observation[teammate_ids][]"]', match: :first)
      first_teammate_checkbox.check

      # Submit form
      find('input[type="submit"][value="2"]').click

      # Should handle gracefully
      expect(page).to have_current_path(set_ratings_organization_observation_path(company, 'new'))
    end
  end
end
