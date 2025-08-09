FactoryBot.define do
  factory :person_identity do
    association :person
    provider { 'google_oauth2' }
    sequence(:uid) { |n| "google_uid_#{n}" }
    sequence(:email) { |n| "user#{n}@example.com" }
    name { "Test User" }
    profile_image_url { "https://lh3.googleusercontent.com/a/test" }
    raw_data do
      {
        'info' => {
          'name' => 'Test User',
          'email' => 'test@example.com',
          'first_name' => 'Test',
          'last_name' => 'User',
          'image' => 'https://lh3.googleusercontent.com/a/test'
        },
        'credentials' => {
          'token' => 'test_token',
          'expires' => true,
          'expires_at' => 1.hour.from_now.to_i
        },
        'extra' => {
          'raw_info' => {
            'id' => '123456789',
            'email' => 'test@example.com',
            'verified_email' => true,
            'name' => 'Test User',
            'given_name' => 'Test',
            'family_name' => 'User',
            'picture' => 'https://lh3.googleusercontent.com/a/test',
            'locale' => 'en'
          }
        }
      }
    end

    trait :google do
      provider { 'google_oauth2' }
    end

    trait :email do
      provider { 'email' }
      uid { email }
      name { nil }
      profile_image_url { nil }
      raw_data { nil }
    end
  end
end
