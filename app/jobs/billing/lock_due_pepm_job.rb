# frozen_string_literal: true

module Billing
  # Per-organization lock when today is calculation day (due − 1 week).
  class LockDuePepmJob < ApplicationJob
    queue_as :default

    def perform(organization_id, as_of: Date.current)
      organization = Organization.find_by(id: organization_id)
      return unless organization

      Organizations::Billing::LockPepm.call(organization: organization, as_of: as_of)
    end
  end
end
