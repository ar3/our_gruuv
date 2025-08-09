# Google OAuth Data Reference

## Login Flow

Our application provides a dedicated login page at `/login` with the following features:

### User Type Selection
- **"I have an account"** - For existing users to sign in
- **"I'm new here"** - For new users to create an account

### Authentication Methods
1. **Google OAuth** - Primary authentication method (fully implemented)
2. **Email** - Coming soon
3. **Phone** - Coming soon

### Login Page Features
- Radio button selection between existing and new users
- Dynamic UI that changes based on user type selection
- Consistent styling with the rest of the application
- Automatic redirect to dashboard if already logged in

## What Data Google OAuth Provides

When a user authenticates with Google OAuth, we receive a comprehensive set of data through the OmniAuth hash (`request.env['omniauth.auth']`).

## Current Scope: `email,profile`

With our current scope configuration, Google provides the following data:

### Basic Information (`auth.info`)
```ruby
auth.info.name          # "John Doe"
auth.info.email         # "john.doe@gmail.com"
auth.info.first_name    # "John"
auth.info.last_name     # "Doe"
auth.info.image         # "https://lh3.googleusercontent.com/a/..."
```

### Unique Identifier (`auth.uid`)
```ruby
auth.uid                # "123456789012345678901" (Google's unique user ID)
```

### Credentials (`auth.credentials`)
```ruby
auth.credentials.token        # "ya29.a0AfH6SMC..." (Access token)
auth.credentials.refresh_token # "1//04d..." (Refresh token, if requested)
auth.credentials.expires_at   # 1234567890 (Unix timestamp)
auth.credentials.expires      # true/false (Whether token expires)
```

### Raw Data (`auth.extra.raw_info`)
This contains the full user profile from Google's People API:

```ruby
auth.extra.raw_info = {
  "id" => "123456789012345678901",
  "email" => "john.doe@gmail.com",
  "verified_email" => true,
  "name" => "John Doe",
  "given_name" => "John",
  "family_name" => "Doe",
  "picture" => "https://lh3.googleusercontent.com/a/...",
  "locale" => "en",
  "hd" => "example.com"  # Hosted domain (if applicable)
}
```

## What We Currently Store

In our `PersonIdentity` model, we currently store:
- `provider`: "google_oauth2"
- `uid`: Google's unique user ID
- `email`: User's email address
- `name`: User's full name (from Google)
- `profile_image_url`: URL to user's Google profile picture
- `raw_data`: Complete JSONB storage of all OAuth response data

## What We Could Store (Future Enhancements)

### Additional PersonIdentity Fields
We could extend the `PersonIdentity` model to store:

```ruby
# Additional fields we could add:
t.string :first_name
t.string :last_name
t.string :profile_image_url
t.string :locale
t.string :hosted_domain
t.boolean :email_verified
t.datetime :last_synced_at
```

### Enhanced Person Model
We could also store additional data in the `Person` model:

```ruby
# Additional Person fields:
t.string :profile_image_url
t.string :locale
t.string :hosted_domain
```

## Extended Scopes (Future)

### Calendar Access (`https://www.googleapis.com/auth/calendar`)
Would provide:
- Calendar list
- Calendar events
- Free/busy information

### Drive Access (`https://www.googleapis.com/auth/drive`)
Would provide:
- File list
- File content
- Sharing permissions

### Gmail Access (`https://www.googleapis.com/auth/gmail.readonly`)
Would provide:
- Email messages
- Labels
- Threads

## Security Considerations

1. **Token Storage**: We don't currently store access tokens (good for security)
2. **Refresh Tokens**: Only available if `access_type: 'offline'` is set
3. **Token Expiration**: Access tokens expire (typically 1 hour)
4. **Scope Minimization**: Only request scopes you actually need

## Current Implementation

Our current implementation stores comprehensive OAuth data:

```ruby
def create_or_update_google_identity(person, auth)
  identity = person.person_identities.find_or_initialize_by(
    provider: 'google_oauth2', 
    uid: auth.uid
  )
  identity.email = auth.info.email
  identity.name = auth.info.name
  identity.profile_image_url = auth.info.image
  identity.raw_data = {
    'info' => {
      'name' => auth.info.name,
      'email' => auth.info.email,
      'first_name' => auth.info.first_name,
      'last_name' => auth.info.last_name,
      'image' => auth.info.image,
      'urls' => auth.info.urls
    },
    'credentials' => {
      'token' => auth.credentials.token,
      'refresh_token' => auth.credentials.refresh_token,
      'expires_at' => auth.credentials.expires_at,
      'expires' => auth.credentials.expires
    },
    'extra' => {
      'raw_info' => auth.extra.raw_info
    }
  }
  identity.save!
end
```

## Debugging

To see the actual data returned by Google:

1. **Check logs**: Look for `🔐 GOOGLE_OAUTH_*` log entries
2. **Debug endpoint**: Visit `/auth/debug` after OAuth callback
3. **Health check**: Visit `/healthcheck` for OAuth configuration status

## Next Steps

1. **Profile Images**: Store and display user profile images
2. **Name Parsing**: Use Google's parsed name data (first_name, last_name)
3. **Email Verification**: Track verified email status
4. **Locale Support**: Use Google's locale for internationalization
5. **Calendar Integration**: Add calendar scope for future features
