FactoryBot.define do
  factory :observable_moment do
    association :company, factory: [:organization, :company]
    association :created_by, factory: :person
    occurred_at { Time.current }
    metadata { {} }
    
    transient do
      primary_observer_person { nil }
      skip_primary_observer_setup { false }
    end
    
    after(:build) do |moment, evaluator|
      # Create or find CompanyTeammate for primary_potential_observer
      # Only set if not already provided and not explicitly skipped
      unless evaluator.skip_primary_observer_setup || moment.primary_potential_observer
        if evaluator.primary_observer_person
          person = evaluator.primary_observer_person
        else
          person = moment.created_by
        end
        
        if moment.company && person
          # Try to find existing teammate first to avoid uniqueness validation errors
          teammate = CompanyTeammate.find_by(person: person, organization: moment.company)
          unless teammate
            teammate = CompanyTeammate.create!(
              person: person,
              organization: moment.company,
              first_employed_at: nil,
              last_terminated_at: nil
            )
          end
          moment.primary_potential_observer = teammate
        end
      end
    end
    
    trait :new_hire do
      moment_type { 'new_hire' }
      association :momentable, factory: :employment_tenure
      after(:build) do |moment|
        moment.company = moment.momentable.company if moment.momentable
      end
    end
    
    trait :seat_change do
      moment_type { 'seat_change' }
      association :momentable, factory: :employment_tenure
      after(:build) do |moment|
        moment.company = moment.momentable.company if moment.momentable
        position = moment.momentable&.position
        position_name = position ? position.display_name : 'New Position'
        moment.metadata = {
          old_position_name: 'Old Position',
          new_position_name: position_name
        }
      end
    end
    
    trait :ability_milestone do
      moment_type { 'ability_milestone' }
      association :momentable, factory: :teammate_milestone
      after(:build) do |moment|
        if moment.momentable
          moment.company = moment.momentable.ability.company
          moment.metadata = {
            ability_id: moment.momentable.ability_id,
            ability_name: moment.momentable.ability.name,
            milestone_level: moment.momentable.milestone_level
          }
        end
      end
    end

    trait :goal_check_in do
      moment_type { 'goal_check_in' }
      association :momentable, factory: :goal_check_in
      after(:build) do |moment|
        if moment.momentable
          moment.company = moment.momentable.goal.company
          moment.metadata = {
            goal_id: moment.momentable.goal_id,
            goal_title: moment.momentable.goal.title,
            confidence_percentage: moment.momentable.confidence_percentage,
            previous_confidence_percentage: (moment.momentable.confidence_percentage || 0) - 25,
            confidence_delta: 25
          }
        end
      end
    end

    trait :birthday do
      moment_type { 'birthday' }
      transient do
        birthday_teammate { nil }
      end
      after(:build) do |moment, evaluator|
        if moment.company
          teammate = evaluator.birthday_teammate
          unless teammate && teammate.organization_id == moment.company.id
            person = create(:person, born_at: 30.years.ago)
            teammate = CompanyTeammate.create!(
              person: person,
              organization: moment.company,
              first_employed_at: 1.year.ago,
              last_terminated_at: nil
            )
          end
          moment.momentable = teammate
        end
      end
    end

    trait :work_anniversary do
      moment_type { 'work_anniversary' }
      transient do
        work_anniversary_teammate { nil }
      end
      after(:build) do |moment, evaluator|
        if moment.company
          teammate = evaluator.work_anniversary_teammate
          unless teammate && teammate.organization_id == moment.company.id
            teammate = CompanyTeammate.create!(
              person: create(:person),
              organization: moment.company,
              first_employed_at: 1.year.ago,
              last_terminated_at: nil
            )
          end
          moment.momentable = teammate
        end
      end
    end
    
    trait :processed do
      processed_at { Time.current }
      
      after(:build) do |moment|
        if moment.company && moment.primary_potential_observer
          moment.processed_by_teammate = moment.primary_potential_observer
        end
      end
    end
    
    trait :with_observation do
      after(:create) do |moment|
        create(:observation, observable_moment: moment, observer: moment.created_by, company: moment.company)
      end
    end
    
    trait :ignored do
      processed_at { Time.current }
      
      after(:build) do |moment|
        if moment.company && moment.primary_potential_observer
          moment.processed_by_teammate = moment.primary_potential_observer
        end
      end
      # No observations created
    end
  end
end

