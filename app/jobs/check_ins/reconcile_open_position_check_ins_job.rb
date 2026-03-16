# frozen_string_literal: true

module CheckIns
  class ReconcileOpenPositionCheckInsJob < ApplicationJob
    queue_as :default

    def perform
      teammate_ids = PositionCheckIn.open.distinct.pluck(:teammate_id)
      teammate_ids.each do |teammate_id|
        teammate = CompanyTeammate.find_by(id: teammate_id)
        next unless teammate

        ReconcileOpenPositionCheckInsService.call(teammate: teammate)
      end
    end
  end
end
