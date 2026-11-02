# frozen_string_literal: true

FactoryBot.define do
  factory :slack_pogo_auto_refresh_enrollment do
    organization
    association :runner_company_teammate, factory: :company_teammate
    association :subject_company_teammate, factory: :company_teammate
    source { SlackPogoAutoRefreshEnrollment::SOURCE_MANUAL }
    last_refreshed_at { nil }
  end
end
