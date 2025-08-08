#!/bin/bash

# Google OAuth Setup Script
# This script helps you set up environment variables for Google OAuth

echo "🔐 Setting up Google OAuth Environment Variables"
echo "================================================"

# Create environment variables file
ENV_FILE=".env.google_oauth"
cat > $ENV_FILE << EOF
# Google OAuth Environment Variables
# Generated on $(date)

# Google OAuth App Configuration
# You'll need to create a Google OAuth app at https://console.cloud.google.com
GOOGLE_CLIENT_ID=your_google_client_id_here
GOOGLE_CLIENT_SECRET=your_google_client_secret_here

# OAuth Redirect URLs
# Development: http://localhost:3000/auth/google_oauth2/callback
# Production: https://yourdomain.com/auth/google_oauth2/callback
EOF

echo ""
echo "📝 Environment variables saved to: $ENV_FILE"
echo ""
echo "🔧 Next Steps:"
echo "1. Go to https://console.cloud.google.com"
echo "2. Create a new project or select an existing one"
echo "3. Enable the Google+ API"
echo "4. Create OAuth 2.0 credentials:"
echo "   - Application type: Web application"
echo "   - Name: Our Gruuv OAuth"
echo "   - Authorized redirect URIs:"
echo "     - http://localhost:3000/auth/google_oauth2/callback (development)"
echo "     - https://yourdomain.com/auth/google_oauth2/callback (production)"
echo "5. Copy your Client ID and Client Secret to $ENV_FILE"
echo "6. Load the environment variables:"
echo "   export \$(cat $ENV_FILE | xargs)"
echo ""
echo "🚀 You can then test the OAuth flow by visiting:"
echo "   http://localhost:3000"

