FactoryBot.define do
  factory :external_project_cache do
    association :cacheable, factory: :one_on_one_link
    source { 'asana' }
    external_project_id { '123456' }
    external_project_url { 'https://app.asana.com/0/123456/789' }
    sections_data { [] }
    items_data { [] }
    has_more_items { false }
    last_synced_at { Time.current }
    association :last_synced_by_teammate, factory: :teammate
  end
end

