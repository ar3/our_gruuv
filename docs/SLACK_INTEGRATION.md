# Slack Integration Documentation

## Overview

Our Gruuv includes a comprehensive Slack integration that allows teams to receive notifications about huddle activities directly in their Slack channels.

## Features

### Automatic Notifications
- **Huddle Created**: Notifies when a new huddle is created
- **Feedback Submitted**: Notifies when participants submit feedback
- **Customizable Channels**: Each huddle can specify its own Slack channel

### Testing & Configuration
- **Connection Testing**: Verify your Slack bot authentication
- **Channel Listing**: View all available channels
- **Test Messages**: Send test messages to verify posting works
- **Configuration Dashboard**: Web interface for managing Slack settings

## Setup

### Development Testing Setup

For testing the OAuth flow locally, you'll need ngrok to expose your local server to the internet:

1. **Install ngrok** (if not already installed):
   ```bash
   brew install ngrok
   ```

2. **Start your Rails server**:
   ```bash
   bin/dev
   ```

3. **Run the setup script**:
   ```bash
   script/setup_slack_oauth_testing.sh
   ```

4. **Load environment variables**:
   ```bash
   source script/load_slack_env.sh
   ```

### 1. Create a Slack App

1. Go to [api.slack.com/apps](https://api.slack.com/apps)
2. Click "Create New App" → "From scratch"
3. Name your app (e.g., "Our Gruuv Huddle Bot")
4. Select your workspace

### 2. Configure Bot Permissions

Add the following OAuth scopes to your Slack app:

**Bot Token Scopes:**
- `chat:write` - Post messages to channels
- `channels:read` - View public channels
- `groups:read` - View private channels
- `users:read` - Read user information

### 3. Configure OAuth Settings

1. Go to "OAuth & Permissions" in your app settings
2. Set the Redirect URL to your ngrok URL + `/slack/oauth/callback`
   - Example: `https://abc123.ngrok.io/slack/oauth/callback`
3. Copy the Client ID and Client Secret

### 4. Install the App

1. Go to "OAuth & Permissions" in your app settings
2. Click "Install to Workspace"
3. Copy the "Bot User OAuth Token" (starts with `xoxb-`)

### 5. Environment Variables

For development testing, the setup script will create a `.env.slack_oauth` file. For production, set these environment variables:

```bash
# OAuth App Configuration (Required for OAuth flow)
SLACK_CLIENT_ID=your_slack_client_id_here
SLACK_CLIENT_SECRET=your_slack_client_secret_here
SLACK_REDIRECT_URI=https://yourdomain.com/slack/oauth/callback

# Fallback Global Configuration (Optional)
SLACK_BOT_TOKEN=xoxb-your-bot-token-here
SLACK_DEFAULT_CHANNEL=#bot-test
SLACK_BOT_USERNAME=gruuv Bot
SLACK_BOT_EMOJI=:handshake:
```

## Usage

### Web Dashboard

Access the Slack integration dashboard at `/slack` to:
- Test your connection
- List available channels
- Send test messages
- View configuration status

### Huddle Creation

When creating a huddle, you can optionally specify a Slack channel:
- Leave blank to use the default channel
- Use format: `#channel-name` or `@username` for DMs

### Automatic Notifications

The system automatically sends notifications for:

1. **Huddle Created** (`:huddle_created`)
   ```
   🎯 New huddle created: *Acme Corp > Engineering - January 15, 2024* by John Doe
   ```

2. **Feedback Submitted** (`:feedback_requested`)
   ```
   📝 Feedback requested for *Acme Corp > Engineering - January 15, 2024* - 75% participation
   ```

3. **Huddle Completed** (`:huddle_completed`)
   ```
   ✅ Huddle completed: *Acme Corp > Engineering - January 15, 2024* - Nat 20 Score: 4.2
   ```

## API Endpoints

### GET `/slack`
- **Purpose**: Slack integration dashboard
- **Authentication**: None required
- **Response**: HTML dashboard page

### GET `/slack/test_connection`
- **Purpose**: Test Slack bot authentication
- **Authentication**: Requires `SLACK_BOT_TOKEN`
- **Response**: JSON with connection status

### GET `/slack/list_channels`
- **Purpose**: List all accessible channels
- **Authentication**: Requires `SLACK_BOT_TOKEN`
- **Response**: JSON with channel list

### POST `/slack/post_test_message`
- **Purpose**: Send a test message
- **Authentication**: Requires `SLACK_BOT_TOKEN`
- **Parameters**: `channel`, `message` (optional)
- **Response**: JSON with message status

### GET `/slack/configuration_status`
- **Purpose**: Get current configuration status
- **Authentication**: None required
- **Response**: JSON with configuration details

## Message Templates

Messages use Ruby string interpolation with the following variables:

- `%{huddle_name}` - Full huddle display name
- `%{creator_name}` - Name of huddle creator
- `%{participation_rate}` - Percentage of participants who submitted feedback
- `%{nat_20_score}` - Average Nat 20 score
- `%{time_until_start}` - Time until huddle starts (for reminders)

## Background Jobs

Slack notifications are sent asynchronously using `SlackNotificationJob`:

```ruby
# Send huddle created notification
SlackNotificationJob.perform_later(huddle.id, :huddle_created, creator_name: 'John Doe')

# Send feedback notification
SlackNotificationJob.perform_later(huddle.id, :feedback_requested)
```

## Troubleshooting

### Common Issues

1. **"Slack bot token not configured"**
   - Ensure `SLACK_BOT_TOKEN` environment variable is set
   - Verify the token starts with `xoxb-`

2. **"Failed to connect to Slack"**
   - Check if the bot token is valid
   - Verify the app is installed in your workspace
   - Ensure the bot has the required permissions

3. **"Failed to post test message"**
   - Check if the bot is invited to the target channel
   - Verify the channel name format (include `#` for public channels)
   - Ensure the bot has `chat:write` permission

4. **Messages not appearing**
   - Check the Rails logs for error messages
   - Verify the background job queue is running
   - Ensure the Slack service is properly configured

### Debugging

Enable detailed logging by checking Rails logs:

```bash
tail -f log/development.log | grep "Slack:"
```

### Testing Locally

1. Set up your environment variables
2. Start the Rails server: `bin/dev`
3. Visit `/slack` to access the dashboard
4. Use the test functions to verify your setup

## Security Considerations

- Bot tokens should be kept secure and never committed to version control
- Use environment variables for all sensitive configuration
- The bot only has the permissions you explicitly grant it
- Consider using private channels for sensitive huddle discussions

## Future Enhancements

Potential improvements for the Slack integration:

- Interactive message buttons for quick actions
- Slash commands for creating huddles directly from Slack
- Rich message formatting with attachments
- Custom notification schedules
- Integration with Slack user profiles
- Support for workspace-specific configurations 