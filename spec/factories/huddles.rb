FactoryBot.define do
  factory :huddle do
    association :organization
    started_at { 1.day.ago }
    
    after(:build) do |huddle|
      # Create a huddle playbook if one doesn't exist
      unless huddle.huddle_playbook
        huddle.huddle_playbook = create(:huddle_playbook, organization: huddle.organization)
      end
    end

    after(:create) do |huddle|
      # Ensure huddle has a playbook after creation
      unless huddle.huddle_playbook
        huddle.update!(huddle_playbook: create(:huddle_playbook, organization: huddle.organization))
      end
    end
  end
end 