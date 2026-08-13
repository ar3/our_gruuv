FactoryBot.define do
  factory :position_suggestion do
    association :position
    organization { position.company }
    association :opened_by, factory: :company_teammate
    status { "open" }

    after(:build) do |suggestion|
      company = suggestion.position.company
      suggestion.organization = company if suggestion.organization.blank?
      if suggestion.opened_by && suggestion.opened_by.organization_id != company.id
        suggestion.opened_by = create(:company_teammate, organization: company)
      end
    end

    trait :completed do
      status { "completed" }
      closed_at { Time.current }
      after(:build) do |suggestion|
        suggestion.closed_by ||= suggestion.opened_by
      end
    end
  end

  factory :position_suggestion_participant do
    association :position_suggestion
    association :company_teammate
    participation_status { "active" }

    after(:build) do |participant|
      org = participant.position_suggestion.organization
      if participant.company_teammate.organization_id != org.id
        participant.company_teammate = create(:company_teammate, organization: org)
      end
    end
  end

  factory :position_suggestion_milestone do
    association :position_suggestion
    association :last_modified_by, factory: :company_teammate
    suggested_milestone_level { 2 }

    after(:build) do |milestone|
      suggestion = milestone.position_suggestion
      org = suggestion.organization
      if milestone.last_modified_by.organization_id != org.id
        milestone.last_modified_by = create(:company_teammate, organization: org)
      end

      if milestone.milestoneable.blank?
        assignment = create(:assignment, company: org)
        ability = create(:ability, company: org)
        create(:position_assignment, position: suggestion.position, assignment: assignment)
        milestone.milestoneable = create(:assignment_ability, assignment: assignment, ability: ability, milestone_level: 1)
      end
    end
  end

  factory :position_suggestion_assignment do
    association :position_suggestion
    association :last_modified_by, factory: :company_teammate
    title { "Suggested Title" }
    tagline { "Suggested tagline" }

    after(:build) do |draft|
      suggestion = draft.position_suggestion
      org = suggestion.organization
      if draft.last_modified_by.organization_id != org.id
        draft.last_modified_by = create(:company_teammate, organization: org)
      end

      if draft.source_assignment.blank?
        assignment = create(:assignment, company: org, title: "Source Assignment")
        create(:position_assignment, position: suggestion.position, assignment: assignment)
        draft.source_assignment = assignment
        draft.title = assignment.title
        draft.tagline = assignment.tagline
      end
    end
  end

  factory :position_suggestion_assignment_link do
    association :position_suggestion
    association :last_modified_by, factory: :company_teammate
    action { "update" }
    assignment_type { "required" }
    min_estimated_energy { 10 }
    max_estimated_energy { 20 }

    after(:build) do |link|
      suggestion = link.position_suggestion
      org = suggestion.organization
      if link.last_modified_by.organization_id != org.id
        link.last_modified_by = create(:company_teammate, organization: org)
      end

      if link.assignment.blank?
        assignment = create(:assignment, company: org, title: "Linked Assignment")
        create(:position_assignment, position: suggestion.position, assignment: assignment) unless link.action == "add"
        link.assignment = assignment
      end
    end

    trait :add do
      action { "add" }
      after(:build) do |link|
        # Ensure assignment is not on the position for add proposals.
        if link.assignment.present?
          PositionAssignment.where(position: link.position_suggestion.position, assignment: link.assignment).delete_all
        end
      end
    end

    trait :remove do
      action { "remove" }
    end
  end

  factory :position_suggestion_assignment_outcome do
    association :position_suggestion_assignment
    description { "Deliver clear discovery notes" }
    outcome_type { "quantitative" }
    position { 0 }
  end
end
