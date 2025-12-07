FactoryBot.define do
  factory :page_visit do
    association :person
    url { "/organizations/1/dashboard" }
    page_title { "Dashboard" }
    user_agent { "Mozilla/5.0" }
    visited_at { Time.current }
    visit_count { 1 }
  end
end

