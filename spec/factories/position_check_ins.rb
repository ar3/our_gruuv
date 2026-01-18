FactoryBot.define do
  factory :position_check_in do
    teammate
    employment_tenure
    check_in_started_on { Date.current }
    
    trait :employee_completed do
      employee_rating { 2 }
      employee_private_notes { "I feel I'm doing well" }
      employee_completed_at { Time.current }
    end
    
    trait :manager_completed do
      manager_rating { 2 }
      manager_private_notes { "Great work" }
      manager_completed_at { Time.current }
      manager_completed_by_teammate { CompanyTeammate.create!(person: create(:person), organization: teammate.organization) }
    end
    
    trait :ready_for_finalization do
      employee_completed
      manager_completed
    end
    
    trait :closed do
      ready_for_finalization
      official_rating { 2 }
      shared_notes { "Finalized notes" }
      official_check_in_completed_at { Time.current }
      finalized_by_teammate { CompanyTeammate.create!(person: create(:person), organization: teammate.organization) }
    end
  end
end




