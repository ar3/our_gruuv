require 'rails_helper'

RSpec.describe "Weekly Notification", type: :system, critical: true do
  let(:person) { create(:person) }
  let(:company) { create(:organization, :company).becomes(Company) }
  let(:slack_config) { create(:slack_configuration, organization: company) }
  let(:slack_channel) { create(:third_party_object, organization: company, third_party_source: 'slack', third_party_object_type: 'channel') }
  let(:association) { create(:third_party_object_association, third_party_object: slack_channel, associatable: company, association_type: 'huddle_review_notification_channel') }

  before do
    # Set up test data
    slack_config
    slack_channel
    association
    
    # Create some test huddles and feedback for the past week
    huddle1 = create(:huddle, huddle_playbook: create(:huddle_playbook, organization: company), started_at: 1.week.ago)
    huddle2 = create(:huddle, huddle_playbook: create(:huddle_playbook, organization: company), started_at: 1.week.ago)
    
    person1 = create(:person)
    person2 = create(:person)
    teammate1 = create(:teammate, person: person1, organization: company)
    teammate2 = create(:teammate, person: person2, organization: company)
    
    create(:huddle_feedback, huddle: huddle1, teammate: teammate1, created_at: 1.week.ago)
    create(:huddle_feedback, huddle: huddle2, teammate: teammate2, created_at: 1.week.ago)
    
    # Sign in as the person using session
    page.set_rack_session(current_person_id: person.id)
    
    # Mock Slack environment variables
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('SLACK_BOT_TOKEN').and_return('xoxb-test-token')
    
    # Mock the Slack service calls
    allow_any_instance_of(SlackService).to receive(:post_message).and_return("success")
    allow_any_instance_of(SlackService).to receive(:update_message).and_return("success")
    allow_any_instance_of(SlackService).to receive(:list_channels).and_return([{"id" => "C123", "name" => "general"}])
    allow_any_instance_of(SlackService).to receive(:list_all_channel_types).and_return([{"id" => "C123", "name" => "general"}])
  end

  it "Page loads without HAML syntax errors" do
    # This test will fail if there are any HAML syntax errors
    expect {
      visit huddles_review_organization_path(company)
    }.not_to raise_error
    
    # Should see the main content
    expect(page).to have_content("Huddles Review")
    expect(page).to have_content("Weekly Notifications Setup")
  end

  it "User can refresh Slack channels" do
    visit huddles_review_organization_path(company)
    
    # Should see the weekly notifications setup section
    expect(page).to have_content("Weekly Notifications Setup")
    expect(page).to have_button("Refresh Channels")
    
    # Click refresh channels button
    click_button "Refresh Channels"
    
    # Should redirect back to the page with success message
    expect(page).to have_current_path(huddles_review_organization_path(company))
    expect(page).to have_content("Slack channels refreshed successfully!")
  end

  it "User can update notification channel" do
    visit huddles_review_organization_path(company)
    
    # Should see the channel dropdown
    expect(page).to have_select("Notification Channel")
    
    # Select a different channel
    select slack_channel.display_name, from: "Notification Channel"
    
    # Click save
    click_button "Save Channel"
    
    # Should see success message
    expect(page).to have_content("Huddle review notification channel updated successfully!")
  end

  it "User can send weekly notification" do
    visit huddles_review_organization_path(company)
    
    # Should see the send notification button
    expect(page).to have_button("Send Weekly Notification")
    
    # Click send weekly notification button
    click_button "Send Weekly Notification"
    
    # Should redirect back to the page with success message
    expect(page).to have_current_path(huddles_review_organization_path(company))
    expect(page).to have_content("Weekly notification sent successfully!")
  end

  it "User sees notification status and Slack link after sending" do
    visit huddles_review_organization_path(company)
    
    # Send the weekly notification
    click_button "Send Weekly Notification"
    
    # Should see success message
    expect(page).to have_content("Weekly notification sent successfully!")
    
    # Find the notification that was created by the job
    # The job creates it with status 'preparing_to_send', so we need to find it by that status
    notification = Notification.where(
      notifiable: company, 
      notification_type: 'huddle_summary'
    ).order(:created_at).last
    
    # Ensure we found the notification
    expect(notification).to be_present
    
    # Update the notification to have a message_id and sent status so the view shows the status
    # Also ensure it's created in the current week so the view can find it
    week_start = Date.current.beginning_of_week(:monday)
    notification.update!(
      message_id: '1234567890.123456', 
      status: 'sent_successfully',
      created_at: week_start + 1.day # Ensure it's in the current week
    )
    
    # Reload the page to see the status
    visit huddles_review_organization_path(company)
    
    # Should now show the notification status - the view shows "Notification sent this week" with a check icon
    expect(page).to have_content("Notification sent this week")
    expect(page).to have_link("View in Slack")
  end

  it "Weekly notification includes huddle count" do
    # Create some huddles for this week
          create(:huddle, huddle_playbook: create(:huddle_playbook, organization: company), started_at: 1.week.ago)
      create(:huddle, huddle_playbook: create(:huddle_playbook, organization: company), started_at: 1.week.ago)
    
    visit huddles_review_organization_path(company)
    
    # Send the notification
    click_button "Send Weekly Notification"
    
    # Should see success message
    expect(page).to have_content("Weekly notification sent successfully!")
    
    # Check that a notification was created with huddle count
    notification = Notification.where(notification_type: 'huddle_summary').last
    expect(notification).to be_present
    expect(notification.fallback_text).to include("huddles")
  end

  it "User sees appropriate messages when Slack is not configured" do
    # Remove Slack configuration
    slack_config.destroy
    
    visit huddles_review_organization_path(company)
    
    # Should see warning message
    expect(page).to have_content("Slack must be configured to set up weekly notifications")
    expect(page).to have_link("Configure Slack")
    
    # Should not see the notification buttons
    expect(page).not_to have_button("Send Weekly Notification")
  end
end 