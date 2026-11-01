# frozen_string_literal: true

module PossibleObservationSlackSearches
  # Subject list: not dismissed, visible to viewer, auto-hide when an OGO already
  # exists for the same Slack message.
  class VisibleSlackPossibleObservations
    def self.call(subject:, viewer:, organization:, search_id: nil)
      new(subject: subject, viewer: viewer, organization: organization, search_id: search_id).call
    end

    def initialize(subject:, viewer:, organization:, search_id: nil)
      @subject = subject
      @viewer = viewer
      @organization = organization
      @search_id = search_id
    end

    def call
      return [] if @viewer.nil? || @subject.nil?

      scope = SlackPossibleObservation.for_subject(@subject).not_dismissed.recent_first
      scope = scope.discovered_by_search(@search_id) if @search_id.present?

      rows = scope.to_a.select { |row| row.visible_to?(@viewer) }
      rows.reject { |row| observation_exists_for?(row) }
    end

    private

    def observation_exists_for?(row)
      DuplicateObservationsForMessage.call(
        organization: @organization,
        channel_id: row.channel_id,
        message_ts: row.message_ts
      ).exists?
    end
  end
end
