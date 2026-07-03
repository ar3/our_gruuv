# frozen_string_literal: true

module EngagementHealth
  # Point-in-time helpers for historical weekly rollups and live cache (reference_time = now).
  module ReferenceTime
    module_function

    def tenure_active_at?(started_at, ended_at, reference_time)
      return false if started_at.blank?

      started_at.to_time.in_time_zone <= reference_time &&
        (ended_at.nil? || ended_at.to_time.in_time_zone > reference_time)
    end

    def employment_tenure_for(teammate:, organization:, reference_time:)
      teammate.employment_tenures
        .where(company: organization)
        .where("started_at <= ?", reference_time)
        .where("ended_at IS NULL OR ended_at > ?", reference_time)
        .order(started_at: :desc)
        .first
    end

    def assignment_tenures_for(teammate:, organization:, reference_time:)
      teammate.assignment_tenures
        .joins(:assignment)
        .where(assignments: { company_id: organization.id })
        .where("assignment_tenures.started_at <= ?", reference_time)
        .where("assignment_tenures.ended_at IS NULL OR assignment_tenures.ended_at > ?", reference_time)
        .where("assignment_tenures.anticipated_energy_percentage > 0")
    end

    def aspirations_for(organization:, reference_time:)
      Aspiration.unscoped
        .where(company_id: organization.id)
        .where("aspirations.created_at <= ?", reference_time)
        .where("aspirations.deleted_at IS NULL OR aspirations.deleted_at > ?", reference_time)
        .order(:sort_order, :name)
    end
  end
end
