# frozen_string_literal: true

module Observations
  # Published OGO scopes for Observations Health cache (Given, Received, authored mix).
  module HealthScopes
    module_function

    def company_ids_for(organization)
      [organization.id]
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

    # Observations the viewer may see (same rules as Observations index / filtered_observations).
    def visible_observations_for_person(current_person, organization)
      return Observation.none if current_person.blank?

      company = organization.root_company || organization
      ObservationVisibilityQuery.new(current_person, company).visible_observations
    end

    def given_scope_for_person(teammate, organization, current_person:)
      given_scope(teammate, organization).merge(visible_observations_for_person(current_person, organization))
    end

    def received_scope_for_person(teammate, organization, current_person:)
      received_scope(teammate, organization).merge(visible_observations_for_person(current_person, organization))
    end
  end
end
