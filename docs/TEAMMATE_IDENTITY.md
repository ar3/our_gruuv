# TeammateIdentity Architecture

## Overview

`TeammateIdentity` is a model that stores organization-scoped third-party integrations for teammates. It mirrors the `PersonIdentity` model but is designed for workspace-level integrations rather than person-level authentication.

## Purpose

The `TeammateIdentity` model separates **person-level identities** (used for authentication) from **organization-level identities** (used for workspace integrations). This provides clear conceptual boundaries and prevents mixing global identities with workspace-specific ones.

## When to Use PersonIdentity vs TeammateIdentity

| Integration Type | Model | Scope | Examples |
|------------------|-------|-------|----------|
| **Person-level** | `PersonIdentity` | Global to person | Google OAuth, GitHub, Email |
| **Organization-level** | `TeammateIdentity` | Scoped to organization | Slack, Jira, Linear, Asana |

### PersonIdentity Examples
- **Google OAuth**: Person logs in once, works across all organizations
- **GitHub**: Person has one GitHub account, used globally
- **Email**: Person's primary email address

### TeammateIdentity Examples
- **Slack**: Person has different Slack user IDs in different workspaces
- **Jira**: Person has different Jira accounts per project/instance
- **Linear**: Person has different Linear accounts per workspace
- **Asana**: Person has different Asana accounts per workspace

## Database Schema

```ruby
create_table :teammate_identities do |t|
  t.references :teammate, null: false, foreign_key: true, index: true
  t.string :provider, null: false        # 'slack', 'jira', 'linear', etc.
  t.string :uid, null: false             # Provider's unique user ID
  t.string :email                        # User's email in that workspace
  t.string :name                         # Display name in that workspace
  t.string :profile_image_url            # Avatar URL
  t.jsonb :raw_data, default: {}        # Full OAuth/API response
  t.timestamps
  
  # Indexes
  t.index [:teammate_id, :provider], name: 'index_teammate_identities_on_teammate_and_provider'
  t.index [:provider, :uid], name: 'index_teammate_identities_on_provider_and_uid', unique: true
end
```

### Key Design Decisions

1. **Unique constraint on `[provider, uid]`**: Prevents duplicate identities across the system
2. **Composite index on `[teammate_id, provider]`**: Enables efficient lookups for specific teammate/provider combinations
3. **JSONB raw_data**: Stores complete OAuth/API responses for future extensibility
4. **Cascade deletion**: When a teammate is destroyed, their identities are automatically cleaned up

## Model Structure

### TeammateIdentity Model

```ruby
class TeammateIdentity < ApplicationRecord
  belongs_to :teammate
  
  # Validations
  validates :provider, presence: true
  validates :uid, presence: true
  validates :uid, uniqueness: { scope: :provider }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  
  # Scopes
  scope :slack, -> { where(provider: 'slack') }
  scope :jira, -> { where(provider: 'jira') }
  scope :linear, -> { where(provider: 'linear') }
  scope :asana, -> { where(provider: 'asana') }
  
  # Provider check methods
  def slack?; provider == 'slack'; end
  def jira?; provider == 'jira'; end
  def linear?; provider == 'linear'; end
  def asana?; provider == 'asana'; end
  
  # Data accessors
  def raw_info; raw_data&.dig('info') || {}; end
  def raw_credentials; raw_data&.dig('credentials') || {}; end
  def raw_extra; raw_data&.dig('extra') || {}; end
  
  # Class methods for finding teammates
  def self.find_teammate_by_slack_id(slack_user_id, organization)
    slack.where(uid: slack_user_id)
         .joins(:teammate)
         .where(teammates: { organization: organization })
         .first&.teammate
  end
end
```

### Teammate Model Updates

```ruby
class Teammate < ApplicationRecord
  has_many :teammate_identities, dependent: :destroy
  
  # Slack helpers
  def slack_identity; teammate_identities.slack.first; end
  def slack_user_id; slack_identity&.uid; end
  def has_slack_identity?; teammate_identities.slack.exists?; end
  
  # Jira helpers
  def jira_identity; teammate_identities.jira.first; end
  def jira_user_id; jira_identity&.uid; end
  def has_jira_identity?; teammate_identities.jira.exists?; end
  
  # Generic finder
  def identity_for(provider)
    teammate_identities.find_by(provider: provider.to_s)
  end
end
```

## Usage Examples

### Creating a Slack Identity

```ruby
# Find teammate by organization
teammate = Teammate.find_by(
  person: person,
  organization: organization
)

# Create or update Slack identity
slack_identity = teammate.teammate_identities.find_or_initialize_by(
  provider: 'slack',
  uid: slack_user_id
)

slack_identity.update!(
  email: slack_email,
  name: slack_display_name,
  profile_image_url: slack_avatar_url,
  raw_data: {
    'info' => {
      'name' => slack_display_name,
      'email' => slack_email,
      'team_id' => slack_team_id,
      'team_name' => slack_workspace_name,
      'image' => slack_avatar_url
    },
    'credentials' => {
      'token' => slack_user_token,
      'scope' => scopes
    },
    'extra' => {
      'raw_info' => slack_user_profile_data
    }
  }
)
```

### Finding Teammate by Slack User ID

```ruby
# Find teammate by Slack user ID in specific organization
teammate = TeammateIdentity.find_teammate_by_slack_id('U1234567890', organization)

# Generic finder
teammate = TeammateIdentity.find_teammate_by_provider_id('slack', 'U1234567890', organization)
```

### Accessing Identity Data

```ruby
# Check if teammate has Slack identity
if teammate.has_slack_identity?
  slack_user_id = teammate.slack_user_id
  slack_email = teammate.slack_identity.email
  slack_name = teammate.slack_identity.name
end

# Access raw OAuth data
slack_info = teammate.slack_identity.raw_info
slack_credentials = teammate.slack_identity.raw_credentials
slack_extra = teammate.slack_identity.raw_extra
```

## Adding New Providers

To add support for a new provider (e.g., Notion):

### 1. Add Scope and Helper Method

```ruby
# In TeammateIdentity model
scope :notion, -> { where(provider: 'notion') }

def notion?
  provider == 'notion'
end
```

### 2. Add Teammate Helper Methods

```ruby
# In Teammate model
def notion_identity
  teammate_identities.notion.first
end

def notion_user_id
  notion_identity&.uid
end

def has_notion_identity?
  teammate_identities.notion.exists?
end
```

### 3. Update Factory

```ruby
# In spec/factories/teammate_identities.rb
trait :notion do
  provider { 'notion' }
  sequence(:uid) { |n| "notion_user_#{n}" }
  # ... other provider-specific data
end
```

### 4. Update Tests

Add tests for the new provider in both `teammate_identity_spec.rb` and `teammate_spec.rb`.

## OAuth Integration Patterns

### Slack OAuth Flow

```ruby
class SlackController < ApplicationController
  def oauth_callback
    auth = request.env['omniauth.auth']
    
    # Find teammate by organization context
    teammate = Teammate.find_by(
      person: current_person,
      organization: current_organization
    )
    
    # Create/update Slack identity
    slack_identity = teammate.teammate_identities.find_or_initialize_by(
      provider: 'slack',
      uid: auth.uid
    )
    
    slack_identity.update!(
      email: auth.info.email,
      name: auth.info.name,
      profile_image_url: auth.info.image,
      raw_data: {
        'info' => auth.info.to_hash,
        'credentials' => auth.credentials.to_hash,
        'extra' => auth.extra.to_hash
      }
    )
    
    redirect_to organization_employees_path(current_organization), 
                notice: 'Slack account connected successfully!'
  end
end
```

### Webhook Processing

```ruby
class SlackWebhookController < ApplicationController
  def user_updated
    slack_user_id = params[:event][:user][:id]
    organization = find_organization_by_team_id(params[:team_id])
    
    # Find teammate by Slack user ID
    teammate = TeammateIdentity.find_teammate_by_slack_id(slack_user_id, organization)
    
    if teammate
      # Update Slack identity with new data
      slack_identity = teammate.slack_identity
      slack_identity.update!(
        name: params[:event][:user][:real_name],
        profile_image_url: params[:event][:user][:profile][:image_192],
        raw_data: slack_identity.raw_data.merge(
          'extra' => slack_identity.raw_extra.merge(
            'raw_info' => params[:event][:user]
          )
        )
      )
    end
  end
end
```

## Testing

### Factory Usage

```ruby
# Create Slack identity
slack_identity = create(:teammate_identity, :slack, teammate: teammate)

# Create Jira identity
jira_identity = create(:teammate_identity, :jira, teammate: teammate)

# Create with custom data
slack_identity = create(:teammate_identity, :slack, 
                       teammate: teammate, 
                       uid: 'U1234567890',
                       email: 'john@company.com')
```

### Test Examples

```ruby
RSpec.describe TeammateIdentity do
  describe 'Slack integration' do
    let(:teammate) { create(:teammate) }
    let(:slack_identity) { create(:teammate_identity, :slack, teammate: teammate) }
    
    it 'finds teammate by Slack user ID' do
      found_teammate = TeammateIdentity.find_teammate_by_slack_id(
        slack_identity.uid, 
        teammate.organization
      )
      expect(found_teammate).to eq(teammate)
    end
    
    it 'provides helper methods on teammate' do
      expect(teammate.has_slack_identity?).to be true
      expect(teammate.slack_user_id).to eq(slack_identity.uid)
      expect(teammate.slack_identity).to eq(slack_identity)
    end
  end
end
```

## Migration Strategy

If you have existing Slack user IDs stored elsewhere:

1. **Create the migration** (already done)
2. **Run the migration**: `rails db:migrate`
3. **Migrate existing data**:

```ruby
# One-time migration script
Teammate.find_each do |teammate|
  if teammate.respond_to?(:slack_user_id) && teammate.slack_user_id.present?
    teammate.teammate_identities.create!(
      provider: 'slack',
      uid: teammate.slack_user_id,
      email: teammate.person.email,
      name: teammate.person.display_name,
      raw_data: { 'migrated' => true }
    )
  end
end
```

4. **Remove old columns** (in a separate migration):

```ruby
remove_column :teammates, :slack_user_id
remove_column :teammates, :slack_email
# etc.
```

## Security Considerations

1. **Token Storage**: Store OAuth tokens in `raw_data['credentials']` for future API calls
2. **Token Encryption**: Consider encrypting sensitive tokens if storing them
3. **Scope Validation**: Validate OAuth scopes match expected permissions
4. **Access Control**: Use Pundit policies to control who can view/edit identities
5. **Audit Trail**: Consider adding audit logging for identity changes

## Performance Considerations

1. **Indexes**: The composite indexes ensure efficient lookups
2. **Includes**: Use `includes(:teammate_identities)` when loading teammates
3. **Caching**: Consider caching frequently accessed identity data
4. **Batch Operations**: Use `find_each` for bulk operations on identities

## Future Enhancements

1. **Identity Sync**: Add background jobs to sync identity data from providers
2. **Identity Validation**: Add methods to validate identity data is still current
3. **Identity Analytics**: Track identity usage patterns
4. **Identity Templates**: Create templates for common provider integrations
5. **Identity Policies**: Add Pundit policies for identity access control
