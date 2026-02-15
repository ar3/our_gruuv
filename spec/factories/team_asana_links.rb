# frozen_string_literal: true

FactoryBot.define do
  factory :team_asana_link do
    association :team
    url { 'https://app.asana.com/0/123456/789' }
    deep_integration_config { {} }
  end
end
