FactoryBot.define do
  factory :one_on_one_link do
    association :teammate
    url { 'https://example.com' }
    deep_integration_config { {} }
  end
end

