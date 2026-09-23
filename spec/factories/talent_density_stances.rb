# frozen_string_literal: true

FactoryBot.define do
  factory :talent_density_stance do
    association :company_teammate, factory: [:company_teammate, :assigned_employee]
    company { company_teammate.organization }
    period_month { TalentDensityStance.current_period_month }
    stance { :fine_either_way }
    notes { "Solid fit" }
  end
end
