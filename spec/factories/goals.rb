FactoryBot.define do
  factory :goal do
    title { "Sample Goal" }
    description { "A sample goal description" }
    goal_type { 'inspirational_objective' }
    earliest_target_date { Date.today + 1.month }
    latest_target_date { Date.today + 3.months }
    most_likely_target_date { Date.today + 2.months }
    privacy_level { 'only_creator' }
    
    association :creator, factory: :teammate
    association :owner, factory: :teammate
    
    # Set company_id based on creator's organization
    after(:build) do |goal|
      if goal.most_likely_target_date.present?
        # If most_likely is set but earliest/latest aren't, or if ordering is invalid, fix it
        if goal.earliest_target_date.nil? || goal.earliest_target_date > goal.most_likely_target_date
          goal.earliest_target_date = goal.most_likely_target_date - 1.month
        end
        if goal.latest_target_date.nil? || goal.latest_target_date < goal.most_likely_target_date
          goal.latest_target_date = goal.most_likely_target_date + 1.month
        end
      end
      
      # Set company_id from creator's organization
      if goal.creator && goal.company_id.nil?
        company = goal.creator.organization.root_company || goal.creator.organization
        goal.company_id = company.id if company&.company?
      end
      
      # Explicitly set owner_type based on owner's actual type
      # Use explicit types (CompanyTeammate, Company, Department, Team) instead of base class
      if goal.owner.present?
        if goal.owner.respond_to?(:type)
          if goal.owner.type == 'CompanyTeammate'
            goal.owner_type = 'CompanyTeammate'
          elsif goal.owner.type.in?(['Department', 'Team', 'Company'])
            goal.owner_type = goal.owner.type
          end
        elsif goal.owner.is_a?(CompanyTeammate)
          goal.owner_type = 'CompanyTeammate'
        elsif goal.owner.is_a?(Organization)
          goal.owner_type = goal.owner.type
        end
      end
    end
    
    after(:create) do |goal|
      # Ensure owner_type is set correctly after creation as well
      # This handles cases where owner is set during creation
      if goal.owner.present?
        correct_owner_type = if goal.owner.respond_to?(:type)
          if goal.owner.type == 'CompanyTeammate'
            'CompanyTeammate'
          elsif goal.owner.type.in?(['Department', 'Team', 'Company'])
            goal.owner.type
          else
            nil
          end
        elsif goal.owner.is_a?(CompanyTeammate)
          'CompanyTeammate'
        elsif goal.owner.is_a?(Organization)
          goal.owner.type
        else
          nil
        end
        
        if correct_owner_type && goal.owner_type != correct_owner_type
          goal.update_column(:owner_type, correct_owner_type)
        end
      end
    end
    
    trait :inspirational_objective do
      goal_type { 'inspirational_objective' }
    end
    
    trait :qualitative_key_result do
      goal_type { 'qualitative_key_result' }
    end
    
    trait :quantitative_key_result do
      goal_type { 'quantitative_key_result' }
    end
    
    trait :with_teammate_owner do
      association :owner, factory: :teammate
    end
    
    trait :with_company_owner do
      association :owner, factory: :company
    end
    
    trait :with_department_owner do
      association :owner, factory: :department
    end
    
    trait :with_team_owner do
      association :owner, factory: :team
    end
    
    trait :only_creator do
      privacy_level { 'only_creator' }
    end
    
    trait :only_creator_and_owner do
      privacy_level { 'only_creator_and_owner' }
    end
    
    trait :only_creator_owner_and_managers do
      privacy_level { 'only_creator_owner_and_managers' }
    end
    
    trait :everyone_in_company do
      privacy_level { 'everyone_in_company' }
    end
    
    trait :draft do
      started_at { nil }
      completed_at { nil }
      cancelled_at { nil }
    end
    
    trait :active do
      started_at { 1.day.ago }
      completed_at { nil }
      cancelled_at { nil }
    end
    
    trait :completed do
      started_at { 1.week.ago }
      completed_at { 1.day.ago }
      cancelled_at { nil }
    end
    
    trait :cancelled do
      started_at { 1.week.ago }
      completed_at { nil }
      cancelled_at { 1.day.ago }
    end
    
    trait :top_priority do
      became_top_priority { 1.day.ago }
    end
  end
end



