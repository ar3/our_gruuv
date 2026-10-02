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
    content_schema_version { MaapProposals::AssignmentPayload::SCHEMA_VERSION }
    based_on_semantic_version { proposable.try(:semantic_version) || "0.0.1" }
    proposed_payload do
      {
        "schema_version" => MaapProposals::AssignmentPayload::SCHEMA_VERSION,
        "title" => proposable.try(:title) || "Proposed Title",
        "tagline" => proposable.try(:tagline) || "Proposed tagline",
        "required_activities" => proposable.try(:required_activities),
        "handbook" => proposable.try(:handbook),
        "department_id" => proposable.try(:department_id),
        "outcomes" => [],
        "ability_milestones" => [],
        "consumer_assignment_ids" => [],
        "supplier_assignment_ids" => []
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

    trait :create_kind do
      kind { "create" }
      proposable { nil }
      create_key { SecureRandom.uuid }
      based_on_semantic_version { nil }
      proposed_payload do
        {
          "schema_version" => MaapProposals::AssignmentPayload::SCHEMA_VERSION,
          "title" => "New Assignment",
          "tagline" => "Describe this assignment",
          "required_activities" => nil,
          "handbook" => nil,
          "department_id" => nil,
          "outcomes" => [],
          "ability_milestones" => [],
          "consumer_assignment_ids" => [],
          "supplier_assignment_ids" => []
        }
      end
    end

    trait :ability_edit do
      transient do
        ability { nil }
      end

      proposable { ability || association(:ability, company: organization) }
      organization { proposable.company }
      based_on_semantic_version { proposable.try(:semantic_version) || "0.0.1" }
      content_schema_version { MaapProposals::AbilityPayload::SCHEMA_VERSION }
      proposed_payload do
        {
          "schema_version" => MaapProposals::AbilityPayload::SCHEMA_VERSION,
          "name" => proposable.try(:name) || "Proposed Ability",
          "description" => proposable.try(:description) || "Proposed description",
          "department_id" => proposable.try(:department_id),
          "milestone_1_description" => proposable.try(:milestone_1_description) || "Milestone one",
          "milestone_2_description" => proposable.try(:milestone_2_description),
          "milestone_3_description" => proposable.try(:milestone_3_description),
          "milestone_4_description" => proposable.try(:milestone_4_description),
          "milestone_5_description" => proposable.try(:milestone_5_description)
        }
      end
    end

    trait :ability_create do
      kind { "create" }
      proposable { nil }
      proposable_type { "Ability" }
      create_key { SecureRandom.uuid }
      based_on_semantic_version { nil }
      content_schema_version { MaapProposals::AbilityPayload::SCHEMA_VERSION }
      proposed_payload do
        {
          "schema_version" => MaapProposals::AbilityPayload::SCHEMA_VERSION,
          "name" => "New Ability",
          "description" => "Describe this ability",
          "department_id" => nil,
          "milestone_1_description" => Ability.default_milestone_description(1),
          "milestone_2_description" => Ability.default_milestone_description(2),
          "milestone_3_description" => Ability.default_milestone_description(3),
          "milestone_4_description" => Ability.default_milestone_description(4),
          "milestone_5_description" => Ability.default_milestone_description(5)
        }
      end
    end
  end
end
