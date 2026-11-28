# frozen_string_literal: true

FactoryBot.define do
  factory :document do
    sequence(:title) { |n| "Clarity Doc #{n}" }
    kind { "how_to" }
    association :organization
    published_at { Time.current }

    after(:build) do |document|
      if document.owner.blank?
        teammate = create(:teammate, :unassigned_employee, organization: document.organization)
        document.owner = teammate
        document.owner_type = "CompanyTeammate"
      elsif document.owner.is_a?(CompanyTeammate)
        document.owner_type = "CompanyTeammate"
      elsif document.owner.is_a?(Team)
        document.owner_type = "Team"
      elsif document.owner.is_a?(Department)
        document.owner_type = "Department"
      elsif document.owner.is_a?(Organization)
        document.owner_type = "Organization"
      end
    end

    trait :with_text_block do
      transient do
        body { "How we do the work." }
      end

      after(:create) do |document, evaluator|
        document.update!(body: evaluator.body)
      end
    end

    trait :linked_to_assignment do
      transient do
        assignment { nil }
      end

      after(:create) do |document, evaluator|
        link_assignment = evaluator.assignment || create(:assignment, company: document.organization)
        document.document_links.create!(linkable: link_assignment)
      end
    end
  end
end
