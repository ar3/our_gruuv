require 'rails_helper'

RSpec.describe 'Slack Integration', type: :feature do
  let(:company) { create(:organization, name: 'Test Company', type: 'Company') }
  let(:team) { create(:organization, name: 'Test Team', type: 'Team', parent: company) }
  let(:person) { create(:person, first_name: 'John', last_name: 'Doe', email: 'john@example.com', current_organization: team) }

  before do
    # Mock Slack service to avoid actual API calls
    allow_any_instance_of(SlackService).to receive(:post_huddle_notification).and_return(true)
    allow_any_instance_of(SlackService).to receive(:test_connection).and_return({
      'team' => 'Test Team',
      'team_id' => 'T123456',
      'user_id' => 'U123456',
      'user' => 'test-bot'
    })
    allow_any_instance_of(SlackService).to receive(:list_channels).and_return([
      { 'id' => 'C123', 'name' => 'general', 'is_private' => false },
      { 'id' => 'C456', 'name' => 'random', 'is_private' => false }
    ])
    allow_any_instance_of(SlackService).to receive(:post_message).and_return({
      'ts' => '1234567890.123456',
      'channel' => '#general'
    })
  end

  describe 'Slack Dashboard' do
    it 'displays the Slack integration dashboard' do
      # Set up session
      page.set_rack_session(current_person_id: person.id)
      
      visit slack_index_path
      
      expect(page).to have_content('Slack Integration Dashboard')
      expect(page).to have_content('Configuration Status')
      expect(page).to have_content('Test Connection')
      expect(page).to have_content('List Channels')
      expect(page).to have_content('Send Test Message')
    end

    it 'shows configuration status' do
      # Set up session
      page.set_rack_session(current_person_id: person.id)
      
      visit slack_index_path
      
      # Wait for JavaScript to load configuration status
      expect(page).to have_content('Configuration Status')
    end
  end

  describe 'Huddle Creation with Slack Channel' do
    it 'creates a huddle with Slack channel and sends notification' do
      # Set up session
      page.set_rack_session(current_person_id: person.id)
      
      visit new_huddle_path
      
      fill_in 'Company name', with: 'Test Company'
      fill_in 'Team name', with: 'Test Team'
      fill_in 'Huddle alias (optional)', with: 'Daily Standup'
      fill_in 'Slack channel (optional)', with: '#team-huddles'
      fill_in 'Your name', with: 'John Doe'
      fill_in 'Your email', with: 'john@example.com'
      
      click_button 'Start Huddle'
      
      expect(page).to have_content('Huddle created successfully!')
      
      # Verify the huddle was created with the Slack channel
      huddle = Huddle.last
      expect(huddle.slack_channel).to eq('#team-huddles')
      expect(huddle.huddle_alias).to eq('Daily Standup')
    end

    it 'creates a huddle without Slack channel and uses default' do
      # Set up session
      page.set_rack_session(current_person_id: person.id)
      
      visit new_huddle_path
      
      fill_in 'Company name', with: 'Test Company No Slack'
      fill_in 'Team name', with: 'Test Team No Slack'
      fill_in 'Huddle alias (optional)', with: 'No Slack Alias'
      # Do not fill in 'Your name' or 'Your email' since they are readonly when current_person is present
      
      click_button 'Start Huddle'
      
      # Debug: Check if there are any validation errors
      if page.has_content?('error') || page.has_content?('Error')
        puts "Page content: #{page.text}"
        raise "Form submission failed with errors"
      end
      
      expect(page).to have_content('Huddle created successfully!')
      
      # Verify the huddle was created without a specific Slack channel
      huddle = Huddle.last
      expect(huddle.slack_channel).to eq('#general')
    end
  end

  describe 'Feedback Submission with Slack Notification' do
    let(:huddle) { create(:huddle, organization: team, slack_channel: '#team-huddles') }
    let(:participant) { create(:huddle_participant, huddle: huddle, person: person, role: 'active') }

    it 'submits feedback and triggers Slack notification' do
      participant # Create the participant
      
      # Set up session
      page.set_rack_session(current_person_id: person.id)
      
      visit feedback_huddle_path(huddle)
      
      # Fill in feedback form using range sliders
      find('#informed_rating').set('4')
      find('#connected_rating').set('5')
      find('#goals_rating').set('4')
      find('#valuable_rating').set('5')
      
      # Select conflict styles
      select 'Compromising', from: 'personal_conflict_style'
      select 'Collaborative', from: 'team_conflict_style'
      
      fill_in 'appreciation', with: 'Great discussion!'
      fill_in 'change_suggestion', with: 'Nothing, it was perfect!'
      
      click_button 'Submit Feedback'
      
      expect(page).to have_content('Thank you for your feedback!')
    end
  end

  describe 'Navigation' do
    it 'includes Slack integration link in navigation' do
      # Set up session
      page.set_rack_session(current_person_id: person.id)
      
      visit root_path
      
      # Click on Collaborate dropdown
      click_link 'Collaborate'
      
      # Should see Slack Integration link
      expect(page).to have_link('Slack Integration')
    end

    it 'navigates to Slack dashboard from navigation' do
      # Set up session
      page.set_rack_session(current_person_id: person.id)
      
      visit root_path
      
      # Click on Collaborate dropdown
      click_link 'Collaborate'
      
      # Click on Slack Integration
      click_link 'Slack Integration'
      
      expect(page).to have_content('Slack Integration Dashboard')
    end
  end
end 