FactoryBot.define do
  factory :enm_partnership do
    sequence(:code) { |n| "XYZ#{n.to_s.rjust(5, '0')}" }
    assessment_codes { ['ABC12345', 'DEF67890'] }
    compatibility_analysis { {} }
    relationship_type { 'H' }
    
    trait :monogamy_focused do
      relationship_type { 'M' }
    end
    
    trait :swing_focused do
      relationship_type { 'S' }
    end
    
    trait :poly_focused do
      relationship_type { 'P' }
    end
    
    trait :hybrid do
      relationship_type { 'H' }
    end
  end
end



