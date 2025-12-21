FactoryBot.define do
  factory :missing_resource_request do
    association :missing_resource
    person { nil }
    ip_address { '192.168.1.1' }
    request_count { 1 }
    user_agent { 'Mozilla/5.0' }
    referrer { nil }
    request_method { 'GET' }
    query_string { nil }
    first_seen_at { Time.current }
    last_seen_at { Time.current }

    trait :with_person do
      association :person
    end

    trait :anonymous do
      person { nil }
    end
  end
end

