FactoryBot.define do
  factory :seat do
    association :position_type
    seat_needed_by { Date.current + 3.months }
    job_classification { "Salaried Exempt" }
    state { :draft }
    
    trait :open do
      state { :open }
    end
    
    trait :filled do
      state { :filled }
    end
    
    trait :archived do
      state { :archived }
    end
    
    trait :with_hr_content do
      reports_to { "Engineering Manager" }
      team { "Platform Engineering" }
      reports { "Junior Developers" }
      measurable_outcomes { "Deliver 3 major features per quarter" }
      seat_disclaimer { "Custom seat disclaimer text" }
      work_environment { "Hybrid work environment" }
      physical_requirements { "Must be able to lift 25 pounds" }
      travel { "Up to 20% travel required" }
      why_needed { "Team expansion due to increased project load" }
      why_now { "Q4 planning shows we need additional capacity" }
      costs_risks { "Risk of missing delivery deadlines without additional headcount" }
    end
  end
end
