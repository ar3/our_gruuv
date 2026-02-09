# frozen_string_literal: true

module ObservableMoments
  # Resolves primary_potential_observer for birthday/work_anniversary moments.
  # Order: (1) org's observable_moment_notifier_teammate, (2) teammate's manager,
  # (3) first teammate in org with can_manage_employment, (4) teammate themselves.
  class PrimaryPotentialObserverResolver
    def self.call(organization:, teammate:)
      new(organization: organization, teammate: teammate).call
    end

    attr_reader :organization, :teammate

    def initialize(organization:, teammate:)
      @organization = organization
      @teammate = teammate
    end

    def call
      observer = organization.observable_moment_notifier_teammate
      return observer if observer.present?

      manager = teammate.active_employment_tenure&.manager_teammate
      return manager if manager.present?

      first_with_manage_employment = organization.teammates.find_by(can_manage_employment: true)
      return first_with_manage_employment if first_with_manage_employment.present?

      teammate
    end
  end
end
