module Observations
  class PageVisitStatsService
    def self.call(observation:, organization:)
      new(observation: observation, organization: organization).call
    end

    def initialize(observation:, organization:)
      @observation = observation
      @organization = organization
    end

    def call
      show_page_url = organization_observation_path(@organization, @observation)
      public_page_url = @observation.decorate.permalink_path

      # Query for visits to either URL
      page_visits = PageVisit.where(url: [show_page_url, public_page_url])

      {
        total_views: page_visits.sum(:visit_count) || 0,
        unique_viewers: page_visits.distinct.count(:person_id) || 0
      }
    end

    private

    def organization_observation_path(organization, observation)
      Rails.application.routes.url_helpers.organization_observation_path(organization, observation)
    end
  end
end
