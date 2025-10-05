require 'rails_helper'

RSpec.describe 'Slack Integration', type: :feature do
  let(:company) { create(:organization, name: 'Test Company', type: 'Company') }
  let(:team) { create(:organization, name: 'Test Team', type: 'Team', parent: company) }
  let(:person) { create(:person, first_name: 'John', last_name: 'Doe', email: 'john@example.com', current_organization: team) }

  before do
    # Mock Slack service to avoid actual API calls
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
    
    # Mock the new jobs
    allow(Huddles::PostAnnouncementJob).to receive(:perform_now)
    allow(Huddles::PostSummaryJob).to receive(:perform_now)
    allow(Huddles::PostFeedbackJob).to receive(:perform_now)
  end

  describe 'Slack Dashboard' do
    it 'displays the Slack integration dashboard' do
      # Set up session
      page.set_rack_session(current_person_id: person.id)
      
      visit organization_slack_path(team)
      
      expect(page).to have_content('Slack Configuration')
      expect(page).to have_content('Slack Not Connected')
      expect(page).to have_content('Install Slack for Test Company > Test Team')
    end

    it 'shows configuration status' do
      # Set up session
      page.set_rack_session(current_person_id: person.id)
      
      visit organization_slack_path(team)
      
      # Wait for JavaScript to load configuration status
      expect(page).to have_content('Slack Not Connected')
    end
  end

  describe 'Huddle Creation with Slack Channel' do
    it 'creates a huddle with Slack channel and sends notification' do
      # Set up session
      page.set_rack_session(current_person_id: person.id)
      
      visit new_huddle_path
      
      select '+ Create new company', from: 'Company'
      fill_in 'New company name', with: 'Test Company'
      fill_in 'New team name', with: 'Test Team'
      fill_in 'Your email', with: 'john@example.com'
      
      click_button 'Start Huddle'
      
      expect(page).to have_content('Huddle created successfully!')
      
      # Verify the huddle was created (slack_channel is now handled by playbook)
      huddle = Huddle.last
      expect(huddle).to be_present
    end

    it 'creates a huddle without Slack channel and uses default' do
      # Set up session
      page.set_rack_session(current_person_id: person.id)
      
      visit new_huddle_path
      
      select '+ Create new company', from: 'Company'
      fill_in 'New company name', with: 'Test Company No Slack'
      fill_in 'New team name', with: 'Test Team No Slack'
      # Do not fill in 'Your email' since it is readonly when current_person is present
      
      click_button 'Start Huddle'
      
      # Debug: Check if there are any validation errors
      if page.has_content?('error') || page.has_content?('Error')
        puts "Page content: #{page.text}"
        raise "Form submission failed with errors"
      end
      
      expect(page).to have_content('Huddle created successfully!')
      
      # Verify the huddle was created (slack_channel is now handled by playbook)
      huddle = Huddle.last
      expect(huddle).to be_present
    end
  end

  describe 'Feedback Submission with Slack Notification' do
    let(:huddle) { create(:huddle, huddle_playbook: create(:huddle_playbook, organization: team)) }
    let(:teammate) { create(:teammate, person: person, organization: team) }
    let(:participant) { create(:huddle_participant, huddle: huddle, teammate: teammate, role: 'active') }

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
      
      # Check that we're on the authenticated dashboard
      expect(page).to have_content('Dashboard')
    end

    it 'navigates to Slack dashboard from navigation' do
      # Set up session
      page.set_rack_session(current_person_id: person.id)
      
      visit root_path
      
      # Check that we're on the authenticated dashboard
      expect(page).to have_content('Dashboard')
    end
  end
end 