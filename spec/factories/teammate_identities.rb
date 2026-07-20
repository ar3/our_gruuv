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

    trait :slack_search do
      provider { 'slack_search' }
      sequence(:uid) { |n| "U#{SecureRandom.hex(8)}_#{n}" }
      raw_data do
        {
          'info' => {
            'id' => 'USEARCH123',
            'name' => 'searchuser',
            'real_name' => 'Search User'
          },
          'credentials' => {
            'token' => 'xoxp-test-search-token',
            'scope' => 'search:read',
            'token_type' => 'user',
            'team_id' => 'T1234567890'
          },
          'extra' => {
            'ok' => true,
            'authed_user' => { 'id' => 'USEARCH123', 'access_token' => 'xoxp-test-search-token' }
          }
        }
      end
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

    trait :google_meet do
      provider { 'google_meet' }
      sequence(:uid) { |n| "google_meet_user_#{n}" }
      sequence(:email) { |n| "meet#{n}@example.com" }
      name { "Meet Test User" }
      profile_image_url { "https://lh3.googleusercontent.com/a/default" }
      raw_data do
        {
          'info' => {
            'sub' => 'google_meet_user_123',
            'name' => 'Meet Test User',
            'email' => 'meet@example.com',
            'picture' => 'https://lh3.googleusercontent.com/a/default'
          },
          'credentials' => {
            'token' => 'ya29.test-meet-access-token',
            'refresh_token' => '1//test-meet-refresh-token',
            'expires_at' => 1.hour.from_now.iso8601,
            'scope' => 'https://www.googleapis.com/auth/meetings.space.readonly https://www.googleapis.com/auth/drive.meet.readonly'
          },
          'extra' => {}
        }
      end
    end

    trait :zoom do
      provider { 'zoom' }
      sequence(:uid) { |n| "zoom_user_#{n}" }
      sequence(:email) { |n| "zoom#{n}@example.com" }
      name { "Zoom Test User" }
      profile_image_url { "https://zoom.us/avatar/default" }
      raw_data do
        {
          'info' => {
            'id' => 'zoom_user_123',
            'email' => 'zoom@example.com',
            'first_name' => 'Zoom',
            'last_name' => 'User',
            'display_name' => 'Zoom Test User'
          },
          'credentials' => {
            'token' => 'zoom-test-access-token',
            'refresh_token' => 'zoom-test-refresh-token',
            'expires_at' => 1.hour.from_now.iso8601,
            'scope' => 'cloud_recording:read:list_user_recordings'
          },
          'extra' => {}
        }
      end
    end
  end
end
