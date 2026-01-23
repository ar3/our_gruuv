FactoryBot.define do
  factory :maap_snapshot do
    association :employee_company_teammate, factory: :company_teammate
    association :creator_company_teammate, factory: :company_teammate
    association :company, factory: :organization
    
    change_type { 'assignment_management' }
    reason { 'Testing assignment changes' }
    maap_data do
      {
        employment_tenure: nil,
        assignments: [],
        milestones: [],
        aspirations: []
      }
    end
    manager_request_info { { ip_address: '127.0.0.1', user_agent: 'Test Agent' } }
    effective_date { nil }
    
    trait :exploration do
      employee_company_teammate { nil }
      change_type { 'exploration' }
      reason { 'Testing exploration scenario' }
    end
    
    trait :executed do
      effective_date { Date.current }
    end
    
    trait :with_employment_tenure do
      maap_data do
        {
          employment_tenure: {
            position_id: create(:position).id,
            manager_teammate_id: create(:company_teammate).id,
            started_at: Date.current,
            seat_id: nil
          },
          assignments: [],
          milestones: [],
          aspirations: []
        }
      end
    end
    
    trait :with_assignments do
      maap_data do
        {
          employment_tenure: nil,
          assignments: [
            {
              id: create(:assignment).id,
              tenure: {
                anticipated_energy_percentage: 25,
                started_at: Date.current
              },
              employee_check_in: {
                actual_energy_percentage: 30,
                employee_rating: 'exceeding',
                employee_completed_at: Date.current,
                employee_private_notes: 'Feeling confident',
                employee_personal_alignment: 'high'
              },
              manager_check_in: {
                manager_rating: 'meeting',
                manager_completed_at: Date.current,
                manager_private_notes: 'Good progress',
                manager_completed_by_teammate_id: create(:company_teammate).id
              },
              official_check_in: {
                official_rating: 'exceeding',
                shared_notes: 'Great work',
                official_check_in_completed_at: Date.current,
                finalized_by_teammate_id: create(:company_teammate).id
              }
            }
          ],
          milestones: [],
          aspirations: []
        }
      end
    end
  end
end
