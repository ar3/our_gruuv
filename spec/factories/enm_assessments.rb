FactoryBot.define do
  factory :enm_assessment do
    sequence(:code) { |n| "ABC#{n.to_s.rjust(5, '0')}" }
    phase_1_data { {} }
    phase_2_data { {} }
    phase_3_data { {} }
    macro_category { 'P' }
    readiness { 'A' }
    style { 'K' }
    full_code { "#{macro_category}-#{readiness}-#{style}" }
    completed_phase { 3 }
    
    trait :incomplete do
      completed_phase { 1 }
      macro_category { nil }
      readiness { nil }
      style { nil }
      full_code { nil }
    end
    
    trait :monogamy_leaning do
      macro_category { 'M' }
      readiness { 'C' }
      style { 'F' }
      full_code { 'M-C-F' }
    end
    
    trait :swing_leaning do
      macro_category { 'S' }
      readiness { 'A' }
      style { 'H' }
      full_code { 'S-A-H' }
    end
    
    trait :poly_leaning do
      macro_category { 'P' }
      readiness { 'A' }
      style { 'K' }
      full_code { 'P-A-K' }
    end
    
    trait :heart_leaning do
      macro_category { 'H' }
      readiness { 'P' }
      style { 'R' }
      full_code { 'H-P-R' }
    end
  end
end




