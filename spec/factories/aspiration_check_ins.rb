FactoryBot.define do
  factory :aspiration_check_in do
    association :teammate
    association :aspiration
    check_in_started_on { Date.current }
    employee_rating { nil }
    manager_rating { nil }
    official_rating { nil }
    employee_private_notes { nil }
    manager_private_notes { nil }
    shared_notes { nil }
    employee_completed_at { nil }
    manager_completed_at { nil }
    manager_completed_by_teammate { nil }
    finalized_by_teammate { nil }
    official_check_in_completed_at { nil }
    maap_snapshot { nil }
    
    trait :employee_completed do
      employee_completed_at { 1.day.ago }
      employee_rating { 'meeting' }
      employee_private_notes { 'Employee notes' }
    end
    
    trait :manager_completed do
      manager_completed_at { 1.day.ago }
      manager_rating { 'meeting' }
      manager_private_notes { 'Manager notes' }
      manager_completed_by_teammate { CompanyTeammate.create!(person: create(:person), organization: teammate.organization) }
    end
    
    trait :ready_for_finalization do
      employee_completed_at { 1.day.ago }
      manager_completed_at { 1.day.ago }
      employee_rating { 'meeting' }
      manager_rating { 'meeting' }
      employee_private_notes { 'Employee notes' }
      manager_private_notes { 'Manager notes' }
      manager_completed_by_teammate { CompanyTeammate.create!(person: create(:person), organization: teammate.organization) }
    end
    
    trait :finalized do
      employee_completed_at { 2.days.ago }
      manager_completed_at { 2.days.ago }
      official_check_in_completed_at { 1.day.ago }
      employee_rating { 'meeting' }
      manager_rating { 'meeting' }
      official_rating { 'meeting' }
      employee_private_notes { 'Employee notes' }
      manager_private_notes { 'Manager notes' }
      shared_notes { 'Shared notes' }
      manager_completed_by_teammate { CompanyTeammate.create!(person: create(:person), organization: teammate.organization) }
      finalized_by_teammate { CompanyTeammate.create!(person: create(:person), organization: teammate.organization) }
    end
  end
end






