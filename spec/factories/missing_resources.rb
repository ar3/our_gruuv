FactoryBot.define do
  factory :missing_resource do
    path { '/our/explore/choose_roles' }
    request_count { 0 }
    first_seen_at { Time.current }
    last_seen_at { Time.current }
  end
end

