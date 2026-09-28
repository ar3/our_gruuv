# frozen_string_literal: true

FactoryBot.define do
  factory :maap_proposal do
    transient do
      assignment { nil }
    end

    organization { assignment&.company || association(:organization) }
    proposer { association(:company_teammate, :unassigned_employee, organization: organization) }
    proposable { assignment || association(:assignment, company: organization) }
    kind { "edit" }
    status { "draft" }
    source { "in_product" }
    content_schema_version { 1 }
    based_on_semantic_version { proposable.try(:semantic_version) || "0.0.1" }
    proposed_payload do
      {
        "schema_version" => 1,
        "title" => proposable.try(:title) || "Proposed Title",
        "tagline" => proposable.try(:tagline) || "Proposed tagline",
        "required_activities" => proposable.try(:required_activities),
        "handbook" => proposable.try(:handbook),
        "department_id" => proposable.try(:department_id),
        "published_source_url" => nil,
        "draft_source_url" => nil,
        "outcomes" => []
      }
    end

    trait :submitted do
      status { "submitted" }
      submitted_at { Time.current }
    end

    trait :applied do
      status { "applied" }
      submitted_at { 1.day.ago }
      decided_at { Time.current }
      applied_version_type { "clarifying" }
    end

    trait :rejected do
      status { "rejected" }
      submitted_at { 1.day.ago }
      decided_at { Time.current }
    end
  end
end
