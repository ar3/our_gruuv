# frozen_string_literal: true

module CheckIns
  module SlackOgoConsult
    # Finds a Slack search about +subject+ that the viewer consulted within RECENT_WINDOW.
    class RecentSearchFinder
      def self.call(viewer:, subject_teammate:)
        new(viewer: viewer, subject_teammate: subject_teammate).call
      end

      def initialize(viewer:, subject_teammate:)
        @viewer = viewer
        @subject_teammate = subject_teammate
      end

      def call
        return nil if @viewer.blank? || @subject_teammate.blank?

        consultation = recent_consultations.detect do |row|
          batch = row.subject
          next false unless batch.is_a?(PossibleObservationSlackSearchBatch)

          search = batch.possible_observation_slack_search
          search.subject_company_teammate_id == @subject_teammate.id &&
            search.organization_id == @subject_teammate.organization_id
        end
        consultation&.subject&.possible_observation_slack_search
      end

      private

      def recent_consultations
        OgConsultation
          .where(
            kind: OgConsultation::KIND_OGO_SEARCH_SLACK,
            triggered_by_teammate_id: @viewer.id,
            subject_type: "PossibleObservationSlackSearchBatch"
          )
          .where("og_consultations.created_at >= ?", RECENT_WINDOW.ago)
          .includes(subject: :possible_observation_slack_search)
          .latest_first
      end
    end
  end
end
