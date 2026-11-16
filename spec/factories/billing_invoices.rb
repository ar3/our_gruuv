# frozen_string_literal: true

FactoryBot.define do
  factory :billing_invoice do
    organization
    status { "open" }
    cadence { "monthly" }
    period_starts_on { Date.current.beginning_of_month }
    period_ends_on { Date.current.end_of_month }
    due_on { period_starts_on }
    pepm { 1.5 }
    teammate_count { 1 }
    amount_due { 1.5 }
    value_delivered_total { 10.0 }
    value_based_pepm { 1.5 }
  end
end
