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

    # Positive-energy tenures for one assignment that had started by
    # reference_time (including ended ones). Used to measure consecutive
    # tenure age; 0% rows are excluded so they never bridge a chain.
    def positive_energy_assignment_tenures_history(teammate:, assignment_id:, reference_time:)
      teammate.assignment_tenures
        .where(assignment_id: assignment_id)
        .where("assignment_tenures.started_at <= ?", reference_time)
        .where("assignment_tenures.anticipated_energy_percentage > 0")
        .order(:started_at, :id)
    end

    # Start of the consecutive >0% energy tenure chain active at reference_time.
    # Energy reallocations with no calendar gap keep the same start; any gap
    # between prior.ended_at and the next started_at breaks the chain.
    # tenures: ascending by started_at; only >0% energy; 0% must not be included.
    def consecutive_positive_energy_tenure_started_at(tenures, reference_time:)
      list = Array(tenures)
      active_index = list.rindex do |tenure|
        tenure_active_at?(tenure.started_at, tenure.ended_at, reference_time)
      end
      return nil if active_index.nil?

      chain_start = list[active_index].started_at
      index = active_index
      while index.positive?
        prior = list[index - 1]
        current = list[index]
        break if prior.ended_at.blank?
        break if calendar_gap?(prior.ended_at, current.started_at)

        chain_start = prior.started_at
        index -= 1
      end
      chain_start
    end

    def calendar_gap?(ended_at, next_started_at)
      return true if ended_at.blank? || next_started_at.blank?

      next_started_at.to_date > ended_at.to_date + 1
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
