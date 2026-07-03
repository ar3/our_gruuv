# frozen_string_literal: true

module EngagementHealth
  # Recalculates all engagement-health rows for a teammate via the one
  # centralized Calculator and replaces the cached records atomically.
  class Refresher
    def self.call(teammate, organization = nil)
      new(teammate, organization).call
    end

    def initialize(teammate, organization = nil)
      @teammate = teammate
      @organization = organization || teammate.organization
    end

    def call
      rows = Calculator.call(teammate: @teammate, organization: @organization)
      computed_at = Time.current

      EngagementHealthStatus.transaction do
        EngagementHealthStatus.where(teammate: @teammate, organization: @organization).delete_all
        rows.each do |row|
          EngagementHealthStatus.create!(
            row.merge(teammate: @teammate, organization: @organization, computed_at: computed_at)
          )
        end
      end

      rows
    end
  end
end
