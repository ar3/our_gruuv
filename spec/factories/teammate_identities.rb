FactoryBot.define do
  factory :teammate_identity do
    association :teammate
    provider { 'slack' }
    sequence(:uid) { |n| "slack_uid_#{SecureRandom.hex(8)}_#{n}" }
    sequence(:email) { |n| "user#{n}@example.com" }
    name { "Test User" }
    profile_image_url { "https://slack.com/avatar/test.jpg" }
    raw_data do
      {
        'info' => {
          'name' => 'Test User',
          'email' => 'test@example.com',
          'team_id' => 'T1234567890',
          'team_name' => 'Test Workspace',
          'image' => 'https://slack.com/avatar/test.jpg'
        },
        'credentials' => {
          'token' => 'xoxb-test-token',
          'scope' => 'chat:write,users:read'
        },
        'extra' => {
          'raw_info' => {
            'id' => 'U1234567890',
            'name' => 'testuser',
            'real_name' => 'Test User',
            'email' => 'test@example.com',
            'image_24' => 'https://slack.com/avatar/test_24.jpg',
            'image_32' => 'https://slack.com/avatar/test_32.jpg',
            'image_48' => 'https://slack.com/avatar/test_48.jpg',
            'image_72' => 'https://slack.com/avatar/test_72.jpg',
            'image_192' => 'https://slack.com/avatar/test_192.jpg',
            'team' => 'T1234567890'
          }
        }
      }
    end

    trait :slack do
      provider { 'slack' }
      sequence(:uid) { |n| "U#{SecureRandom.hex(8)}_#{n}" }
    end

    trait :jira do
      provider { 'jira' }
      sequence(:uid) { |n| "jira_user_#{n}" }
      sequence(:email) { |n| "jira#{n}@example.com" }
      name { "Jira Test User" }
      profile_image_url { "https://jira.example.com/avatar/test.jpg" }
      raw_data do
        {
          'info' => {
            'name' => 'Jira Test User',
            'email' => 'jira@example.com',
            'accountId' => 'jira_user_123',
            'displayName' => 'Jira Test User',
            'avatarUrls' => {
              '16x16' => 'https://jira.example.com/avatar/test_16.jpg',
              '24x24' => 'https://jira.example.com/avatar/test_24.jpg',
              '32x32' => 'https://jira.example.com/avatar/test_32.jpg',
              '48x48' => 'https://jira.example.com/avatar/test_48.jpg'
            }
          },
          'extra' => {
            'raw_info' => {
              'accountId' => 'jira_user_123',
              'accountType' => 'atlassian',
              'emailAddress' => 'jira@example.com',
              'displayName' => 'Jira Test User'
            }
          }
        }
      end
    end

    trait :linear do
      provider { 'linear' }
      sequence(:uid) { |n| "linear_user_#{n}" }
      sequence(:email) { |n| "linear#{n}@example.com" }
      name { "Linear Test User" }
      profile_image_url { "https://linear.app/avatar/test.jpg" }
      raw_data do
        {
          'info' => {
            'name' => 'Linear Test User',
            'email' => 'linear@example.com',
            'id' => 'linear_user_123',
            'displayName' => 'Linear Test User',
            'avatarUrl' => 'https://linear.app/avatar/test.jpg'
          },
          'extra' => {
            'raw_info' => {
              'id' => 'linear_user_123',
              'name' => 'Linear Test User',
              'email' => 'linear@example.com',
              'avatarUrl' => 'https://linear.app/avatar/test.jpg'
            }
          }
        }
      end
    end

    trait :asana do
      provider { 'asana' }
      sequence(:uid) { |n| "asana_user_#{n}" }
      sequence(:email) { |n| "asana#{n}@example.com" }
      name { "Asana Test User" }
      profile_image_url { "https://asana.com/avatar/test.jpg" }
      raw_data do
        {
          'info' => {
            'name' => 'Asana Test User',
            'email' => 'asana@example.com',
            'id' => 'asana_user_123',
            'gid' => 'asana_user_123',
            'photo' => {
              'image_21x21' => 'https://asana.com/avatar/test_21.jpg',
              'image_27x27' => 'https://asana.com/avatar/test_27.jpg',
              'image_36x36' => 'https://asana.com/avatar/test_36.jpg',
              'image_60x60' => 'https://asana.com/avatar/test_60.jpg',
              'image_128x128' => 'https://asana.com/avatar/test_128.jpg'
            }
          },
          'extra' => {
            'raw_info' => {
              'gid' => 'asana_user_123',
              'name' => 'Asana Test User',
              'email' => 'asana@example.com'
            }
          }
        }
      end
    end
  end
end
