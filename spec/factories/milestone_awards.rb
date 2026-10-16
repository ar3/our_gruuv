# frozen_string_literal: true

FactoryBot.define do
  factory :milestone_award do
    transient do
      org { nil }
    end

    teammate { association :teammate, organization: org || create(:organization) }
    organization { teammate.organization }
    ability { association :ability, company: organization }
    certifying_teammate { association :teammate, organization: organization }
    official_milestone_level { 1 }
    source { "normal" }
    privacy_level { "company" }
    certification_note { "Looks solid" }
    awarder_typed_name { certifying_teammate.person.all_names_display_name }
    awarder_signed_at { Time.current }
    awarder_skipped_cosign_at { Time.current }

    trait :pending_cosign do
      awarder_skipped_cosign_at { nil }
      cosign_requested_at { Time.current }
    end

    trait :cosigned do
      transient do
        cosigner { nil }
      end

      awarder_skipped_cosign_at { nil }
      cosign_requested_at { 1.day.ago }
      cosigning_teammate { cosigner || association(:teammate, organization: organization) }
      cosigner_typed_name { cosigning_teammate.person.all_names_display_name }
      cosigner_reason { "I agree" }
      cosigner_signed_at { Time.current }
    end
  end

  factory :milestone_award_cosign_invite do
    milestone_award { association :milestone_award, :pending_cosign }
    invitee_teammate { association :teammate, organization: milestone_award.organization }
  end
end
