# frozen_string_literal: true

module Observations
  # Enqueues observation health cache rebuilds for everyone involved in an OGO.
  class HealthCacheRefresh
    class << self
      def enqueue_for_observation(observation)
        teammate_ids_for(observation).each do |teammate_id|
          ObservationHealthCacheRefreshJob.perform_later(teammate_id)
          EngagementHealth.schedule_refresh_for(teammate_id)
        end
      end

      def teammate_ids_for(observation)
        ids = observation.observees.map(&:teammate_id).compact
        observer_teammate = observer_teammate_for(observation)
        ids << observer_teammate.id if observer_teammate
        ids.uniq
      end

      def observer_teammate_for(observation)
        observation.company.teammates.find_by(person_id: observation.observer_id)
      end
    end
  end
end
