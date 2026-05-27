# frozen_string_literal: true

module Observations
  # Published OGO scopes for Observations Health cache (Given, Received, authored mix).
  module HealthScopes
    module_function

    def company_ids_for(organization)
      organization.self_and_descendants.pluck(:id)
    end

    def given_scope(teammate, organization)
      Observation
        .published
        .not_soft_deleted
        .not_journal
        .where(observer_id: teammate.person_id)
        .where(company_id: company_ids_for(organization))
    end

    def received_scope(teammate, organization)
      Observation
        .published
        .not_soft_deleted
        .joins(:observees)
        .where(observees: { teammate_id: teammate.id })
        .where(company_id: company_ids_for(organization))
        .where(received_privacy_condition, person_id: teammate.person_id)
    end

    def received_privacy_condition
      <<~SQL.squish
        observations.privacy_level != 'observer_only'
        OR observations.observer_id = :person_id
      SQL
    end
  end
end
