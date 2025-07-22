#!/bin/bash

# Load Slack OAuth Environment Variables
# This script loads the environment variables from .env.slack_oauth

ENV_FILE=".env.slack_oauth"

if [ ! -f "$ENV_FILE" ]; then
    echo "❌ Environment file not found: $ENV_FILE"
    echo "Please run script/setup_slack_oauth_testing.sh first"
    exit 1
fi

echo "🔧 Loading Slack OAuth environment variables..."
export $(cat $ENV_FILE | grep -v '^#' | xargs)

echo "✅ Environment variables loaded:"
echo "  RAILS_HOST: $RAILS_HOST"
echo "  SLACK_CLIENT_ID: $SLACK_CLIENT_ID"
echo "  SLACK_REDIRECT_URI: $SLACK_REDIRECT_URI"

echo ""
echo "🚀 You can now test the Slack OAuth flow!"
echo "Visit: $RAILS_HOST/slack" 