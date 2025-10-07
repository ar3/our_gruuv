FactoryBot.define do
  factory :aspiration do
    association :organization, factory: [:organization, :company]
    name { "Aspiration #{rand(1000)}" }
    sort_order { rand(100) }
  end
end
