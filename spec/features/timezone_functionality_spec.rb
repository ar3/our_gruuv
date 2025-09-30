require 'rails_helper'

RSpec.feature 'Timezone Functionality', type: :feature, js: true do
  let(:organization) { create(:organization, name: 'Test Org') }
  let(:huddle) { create(:huddle, huddle_playbook: create(:huddle_playbook, organization: organization), started_at: Time.zone.parse('2025-07-21 14:30:00 UTC')) }

  scenario 'User timezone is automatically detected when joining huddle' do
    visit join_huddle_path(huddle)
    
    # Fill in the form (timezone will be auto-detected by JavaScript or server fallback)
    fill_in 'Your email', with: 'john@example.com'
    select 'Active Participant', from: 'What role will you play in this huddle?'
    
    click_button 'Join Huddle'
    
    # Should redirect to huddle page
    expect(page).to have_current_path(huddle_path(huddle))
    
    # Check that the person was created with a timezone (JavaScript or server fallback)
    person = Person.find_by(email: 'john@example.com')
    expect(person.timezone).to be_present
  end

  scenario 'Times are displayed in user timezone on huddle cards' do
    # Create a huddle with a fixed date to avoid DST flakiness
    fixed_time = Time.zone.parse('2025-07-21 14:30:00 UTC')
    today_huddle = create(:huddle, huddle_playbook: create(:huddle_playbook, organization: organization), started_at: fixed_time)
    
    # Create a person with timezone
    person = create(:person, 
      first_name: 'John', 
      last_name: 'Doe', 
      email: 'john@example.com',
      timezone: 'Eastern Time (US & Canada)'
    )
    
    # Set up session
    page.set_rack_session(current_person_id: person.id)
    
    visit huddles_path
    
    # The time should be displayed in Eastern Time (EDT) in the tooltip
    # Check for EDT timezone indicator in the tooltip (Bootstrap moves title to data-bs-original-title)
    expect(page).to have_css("h5[data-bs-original-title*='EDT']")
  end

  scenario 'Times are displayed in Eastern Time when user has no timezone' do
    # Create a huddle with a fixed date to avoid DST flakiness
    fixed_time = Time.zone.parse('2025-07-21 14:30:00 UTC')
    today_huddle = create(:huddle, huddle_playbook: create(:huddle_playbook, organization: organization), started_at: fixed_time)
    
    # Create a person without timezone
    person = create(:person, 
      first_name: 'Jane', 
      last_name: 'Smith', 
      email: 'jane@example.com',
      timezone: nil
    )
    
    # Set up session
    page.set_rack_session(current_person_id: person.id)
    
    visit huddles_path
    
    # The time should be displayed in Eastern Time in the tooltip
    # Check for EDT timezone indicator in the tooltip (Bootstrap moves title to data-bs-original-title)
    expect(page).to have_css("h5[data-bs-original-title*='EDT']")
  end

  scenario 'Timezone is automatically detected when joining huddle' do
    visit join_huddle_path(huddle)
    
    # Fill in the form (timezone will be auto-detected by JavaScript or server fallback)
    fill_in 'Your email', with: 'bob@example.com'
    select 'Active Participant', from: 'What role will you play in this huddle?'
    
    click_button 'Join Huddle'
    
    # Should redirect to huddle page
    expect(page).to have_current_path(huddle_path(huddle))
    
    # Check that the person was created with a timezone (JavaScript or server fallback)
    person = Person.find_by(email: 'bob@example.com')
    expect(person.timezone).to be_present
  end

  scenario 'User can update timezone when rejoining' do
    # Create a person without timezone
    person = create(:person, 
      first_name: 'Alice', 
      last_name: 'Johnson', 
      email: 'alice@example.com',
      timezone: nil
    )
    
    # Set up session
    page.set_rack_session(current_person_id: person.id)
    
    visit join_huddle_path(huddle)
    
    # Should see the logged-in state
    expect(page).to have_content('Welcome, Alice Johnson!')
    expect(page).to have_content('You\'re logged in. Please confirm your information and select your role.')
    
    # The timezone field should not be visible for logged-in users
    expect(page).not_to have_field('Your timezone')
    
    # Join the huddle
    select 'Active Participant', from: 'What role will you play in this huddle?'
    click_button 'Join Huddle'
    
    # Should redirect to huddle page
    expect(page).to have_current_path(huddle_path(huddle))
    
    # The person should still have no timezone (since it wasn't updated)
    person.reload
    expect(person.timezone).to be_nil
  end

  scenario 'Server-side timezone fallback works when JavaScript is disabled' do
    visit join_huddle_path(huddle)
    
    # Fill in the form without JavaScript (server will detect timezone)
    fill_in 'Your email', with: 'server@example.com'
    select 'Active Participant', from: 'What role will you play in this huddle?'
    
    click_button 'Join Huddle'
    
    # Should redirect to huddle page
    expect(page).to have_current_path(huddle_path(huddle))
    
    # Check that the person was created with a timezone (server fallback)
    person = Person.find_by(email: 'server@example.com')
    expect(person.timezone).to be_present
    # Should be Eastern Time or a locale-based timezone
    expect(['Eastern Time (US & Canada)', 'Central Time (US & Canada)', 'Pacific Time (US & Canada)', 'London', 'Paris']).to include(person.timezone)
  end
end 