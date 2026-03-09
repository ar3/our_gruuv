# frozen_string_literal: true

FactoryBot.define do
  factory :check_in_health_cache do
    association :teammate, factory: :company_teammate
    association :organization, factory: :organization
    refreshed_at { Time.current }
    payload do
      {
        'position' => { 'category' => 'red', 'employee_completed_at' => nil, 'manager_completed_at' => nil, 'official_check_in_completed_at' => nil, 'acknowledged_at' => nil },
        'assignments' => [],
        'aspirations' => [],
        'milestones' => { 'total_required' => 0, 'earned_count' => 0 }
      }
    end
  end
end
