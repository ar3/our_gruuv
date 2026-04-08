# frozen_string_literal: true

module Goals
  # Resolves manager for Goals Health without N+1 when employment_tenures (+ managers) are preloaded.
  module HealthManagerPerson
    module_function

    def manager_teammate_for(teammate)
      return nil unless teammate

      if teammate.association(:employment_tenures).loaded?
        teammate.employment_tenures
          .select { |t| t.ended_at.nil? }
          .min_by(&:id)
          &.manager_teammate
      else
        teammate.employment_tenures.active.order(:id).includes(manager_teammate: :person).first&.manager_teammate
      end
    end

    def for(teammate)
      manager_teammate_for(teammate)&.person
    end
  end
end
