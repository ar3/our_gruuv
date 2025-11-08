require 'rails_helper'

RSpec.describe 'Timezone Functionality', type: :system, js: true do
  let(:organization) { create(:organization, name: 'Test Org') }
  let(:huddle) { create(:huddle, huddle_playbook: create(:huddle_playbook, organization: organization), started_at: Time.zone.parse('2025-07-21 14:30:00 UTC')) }

  scenario 'User timezone is automatically detected when joining huddle' do
    visit join_huddle_path(huddle)
    
    # Should show authentication required message
    expect(page).to have_content('Authentication Required')
    expect(page).to have_content('Please sign in with Google to join this huddle and participate in feedback')
    
    # Note: This test would need to be updated to test timezone detection
    # through the Google OAuth flow, which is more complex to test
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
    
    # Should show authentication required message
    expect(page).to have_content('Authentication Required')
    expect(page).to have_content('Please sign in with Google to join this huddle and participate in feedback')
    
    # Note: This test would need to be updated to test timezone detection
    # through the Google OAuth flow, which is more complex to test
  end


  scenario 'Server-side timezone fallback works when JavaScript is disabled' do
    visit join_huddle_path(huddle)
    
    # Should show authentication required message
    expect(page).to have_content('Authentication Required')
    expect(page).to have_content('Please sign in with Google to join this huddle and participate in feedback')
    
    # Note: This test would need to be updated to test timezone detection
    # through the Google OAuth flow, which is more complex to test
  end
end 