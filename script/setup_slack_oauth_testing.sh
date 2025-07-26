#!/bin/bash

# Slack OAuth Testing Setup Script
# This script helps you set up ngrok and configure environment variables for testing Slack OAuth

echo "🚀 Setting up Slack OAuth Testing Environment"
echo "=============================================="

# Check if ngrok is installed
if ! command -v ngrok &> /dev/null; then
    echo "❌ ngrok is not installed!"
    echo "Please install ngrok first:"
    echo "  brew install ngrok"
    echo "  or download from https://ngrok.com"
    exit 1
fi

echo "✅ ngrok is installed"

# Check if Rails server is running
if ! curl -s http://localhost:3000 > /dev/null; then
    echo "⚠️  Rails server doesn't appear to be running on port 3000"
    echo "Please start your Rails server first:"
    echo "  bin/dev"
    echo ""
    echo "Then run this script again."
    exit 1
fi

echo "✅ Rails server is running on port 3000"

# Start ngrok with custom domain
echo "🌐 Starting ngrok tunnel with custom domain..."
ngrok http 3000 --domain=crappie-saved-absolutely.ngrok-free.app > /tmp/ngrok.log 2>&1 &
NGROK_PID=$!

# Wait for ngrok to start
sleep 3

# Use the custom domain URL
NGROK_URL="https://crappie-saved-absolutely.ngrok-free.app"

if [ "$NGROK_URL" = "null" ] || [ -z "$NGROK_URL" ]; then
    echo "❌ Failed to get ngrok URL"
    echo "Check ngrok logs: tail -f /tmp/ngrok.log"
    kill $NGROK_PID 2>/dev/null
    exit 1
fi

echo "✅ ngrok tunnel established: $NGROK_URL"

# Create environment variables file
ENV_FILE=".env.slack_oauth"
cat > $ENV_FILE << EOF
# Slack OAuth Testing Environment Variables
# Generated on $(date)

# Your ngrok URL (update this if ngrok restarts)
RAILS_HOST=$NGROK_URL

# Slack OAuth App Configuration
# You'll need to create a Slack app at https://api.slack.com/apps
SLACK_CLIENT_ID=your_slack_client_id_here
SLACK_CLIENT_SECRET=your_slack_client_secret_here
SLACK_REDIRECT_URI=$NGROK_URL/slack/oauth/callback

# Optional: Fallback global configuration
SLACK_BOT_TOKEN=xoxb-your_bot_token_here
SLACK_DEFAULT_CHANNEL=#bot-test
SLACK_BOT_USERNAME=OG
SLACK_BOT_EMOJI=:sparkles:
EOF

echo ""
echo "📝 Environment variables saved to: $ENV_FILE"
echo ""
echo "🔧 Next Steps:"
echo "1. Create a Slack app at https://api.slack.com/apps"
echo "2. Set the OAuth Redirect URL to: $NGROK_URL/slack/oauth/callback"
echo "3. Add these scopes to your Slack app:"
echo "   - chat:write"
echo "   - channels:read"
echo "   - groups:read"
echo "   - users:read"
echo "4. Copy your Client ID and Client Secret to $ENV_FILE"
echo "5. Load the environment variables:"
echo "   export \$(cat $ENV_FILE | xargs)"
echo ""
echo "🌐 Your ngrok tunnel is running at: $NGROK_URL"
echo "📊 ngrok dashboard: http://localhost:4040"
echo ""
echo "To stop ngrok, run: kill $NGROK_PID"
echo "To view ngrok logs: tail -f /tmp/ngrok.log" 