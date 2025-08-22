FactoryBot.define do
  factory :person do
    sequence(:first_name) { |n| "Person#{n}" }
    sequence(:last_name) { |n| "Last#{n}" }
    sequence(:email) { |n| "person#{n}@example.com" }
    sequence(:unique_textable_phone_number) { |n| "+1555#{n.to_s.rjust(7, '0')}" }
    og_admin { false }
    
    trait :admin do
      og_admin { true }
    end
  end
end 