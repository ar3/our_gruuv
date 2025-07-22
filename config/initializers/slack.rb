# Slack API Configuration
require 'slack-ruby-client'

# Configure Slack client
Slack.configure do |config|
  # Bot token for posting messages and interacting with Slack
  config.token = ENV['SLACK_BOT_TOKEN']
end

# Create a global Slack client instance
SLACK_CLIENT = Slack::Web::Client.new

# Slack configuration constants
module SlackConstants
  # Default channel for huddle notifications
  DEFAULT_HUDDLE_CHANNEL = ENV['SLACK_DEFAULT_CHANNEL'] || '#general'
  
  # Bot username for messages
  BOT_USERNAME = ENV['SLACK_BOT_USERNAME'] || 'Huddle Bot'
  
  # Bot emoji for messages
  BOT_EMOJI = ENV['SLACK_BOT_EMOJI'] || ':huddle:'
  
  # Message templates
  MESSAGE_TEMPLATES = {
    huddle_created: "🎯 New huddle created: *%{huddle_name}* by %{creator_name}",
    huddle_started: "🚀 Huddle starting: *%{huddle_name}* - Join now!",
    huddle_reminder: "⏰ Reminder: *%{huddle_name}* starts in %{time_until_start}",
    feedback_requested: "📝 Feedback requested for *%{huddle_name}* - %{participation_rate}%% participation",
    huddle_completed: "✅ Huddle completed: *%{huddle_name}* - Nat 20 Score: %{nat_20_score}"
  }.freeze
end 