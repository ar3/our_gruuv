# frozen_string_literal: true

FactoryBot.define do
  factory :talent_density_stance do
    association :company_teammate, factory: [:company_teammate, :assigned_employee]
    company { company_teammate.organization }
    stance { :fine_either_way }
    notes { "Solid fit" }
  end
end
