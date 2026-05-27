# frozen_string_literal: true

FactoryBot.define do
  factory :observation_health_cache do
    association :teammate, factory: :company_teammate
    association :organization, factory: :organization
    refreshed_at { Time.current }
    payload do
      {
        "given" => { "status" => "red", "last_published_at" => nil },
        "received" => { "status" => "red", "last_published_at" => nil },
        "kudos_mix" => {
          "band" => "no_data",
          "kudos_count" => 0,
          "constructive_count" => 0,
          "display_ratio" => "0:0"
        },
        "rating_intensity" => {
          "band" => "no_data",
          "less_extreme_count" => 0,
          "most_extreme_count" => 0,
          "display_ratio" => "0:0"
        },
        "overall_status" => "red"
      }
    end
  end
end
