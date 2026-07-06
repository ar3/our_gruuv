# frozen_string_literal: true

module Goals
  # Resolves manager for Goals Health without N+1 when employment_tenures (+ managers) are preloaded.
  module HealthManagerPerson
    module_function

    def manager_teammate_for(teammate, company: nil)
      return nil unless teammate

      if teammate.association(:employment_tenures).loaded?
        tenures = teammate.employment_tenures.select { |t| t.ended_at.nil? }
        tenures = tenures.select { |t| t.company_id == company.id } if company
        tenures.min_by(&:id)&.manager_teammate
      else
        scope = teammate.employment_tenures.active.order(:id).includes(manager_teammate: :person)
        scope = scope.where(company: company) if company
        scope.first&.manager_teammate
      end
    end

    def for(teammate, company: nil)
      manager_teammate_for(teammate, company: company)&.person
    end
  end
end
