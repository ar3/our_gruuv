require 'rails_helper'

RSpec.feature 'Huddle Sharing', type: :feature, js: true do
  let(:organization) { create(:organization, name: 'Test Org') }
  let(:huddle) { create(:huddle, organization: organization, started_at: Time.current) }
  let(:person) { create(:person, first_name: 'John', last_name: 'Doe', email: 'john@example.com') }
  let!(:participant) { create(:huddle_participant, huddle: huddle, person: person, role: 'active') }

  before do
    # Set up session
    page.set_rack_session(current_person_id: person.id)
  end

  scenario 'User can share a huddle from the index page' do
    visit huddles_path
    
    # Find the share button for the huddle
    share_button = find('.share-huddle-btn')
    
    # Verify tooltip is present
    expect(share_button['title']).to eq('Share this huddle')
    
    # Verify the join URL is in the data attribute (should match the actual test server URL)
    expect(share_button['data-join-url']).to include("/huddles/#{huddle.id}/join")
    
    # Verify the button has the correct structure
    expect(share_button).to have_css('.bi-link-45deg')
  end

  scenario 'User can share a huddle from my huddles page' do
    visit my_huddles_path
    
    # Find the share button for the huddle
    share_button = find('.share-huddle-btn')
    
    # Verify the button has the correct structure
    expect(share_button).to have_css('.bi-link-45deg')
    expect(share_button['data-join-url']).to include("/huddles/#{huddle.id}/join")
  end

  scenario 'Share button is positioned correctly on huddle cards' do
    visit huddles_path
    
    # Check that share buttons are positioned in top-right corner
    share_buttons = page.all('.share-huddle-btn')
    expect(share_buttons.length).to be > 0
    
    share_buttons.each do |button|
      # The button should be inside a card-body with position-relative
      card_body = button.find(:xpath, './ancestor::div[contains(@class, "card-body")]')
      expect(card_body['class']).to include('position-relative')
      
      # The button should be in a position-absolute container
      button_container = button.find(:xpath, './ancestor::div[contains(@class, "position-absolute")]')
      expect(button_container['class']).to include('top-0', 'end-0')
    end
  end

  scenario 'Share button shows link icon' do
    visit huddles_path
    
    share_button = find('.share-huddle-btn')
    expect(share_button).to have_css('.bi-link-45deg')
  end

  scenario 'Share button has correct positioning and styling' do
    visit huddles_path
    
    share_button = find('.share-huddle-btn')
    
    # Verify positioning classes
    expect(page).to have_css('.card-body.position-relative')
    expect(page).to have_css('.position-absolute.top-0.end-0')
    
    # Verify button has the essential attributes
    expect(share_button['title']).to eq('Share this huddle')
    expect(share_button['data-huddle-id']).to eq(huddle.id.to_s)
    expect(share_button['data-join-url']).to include("/huddles/#{huddle.id}/join")
  end
end 