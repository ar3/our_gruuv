FactoryBot.define do
  factory :missing_resource do
    sequence(:path) { |n| "/missing/path/#{n}" }
    request_count { 0 }
    first_seen_at { Time.current }
    last_seen_at { Time.current }
  end
end

