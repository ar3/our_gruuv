# frozen_string_literal: true

module PossibleObservationSlackSearches
  # Subject list: not dismissed, visible to viewer, auto-hide when a *published*
  # OGO exists for the same Slack message. Draft OGOs keep the row visible.
  class VisibleSlackPossibleObservations
    Row = Data.define(:moment, :draft_observation)

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

      scope.to_a.filter_map do |moment|
        next unless moment.visible_to?(@viewer)

        linked = linked_observations(moment)
        next if linked.any?(&:published?)

        Row.new(moment: moment, draft_observation: linked.find(&:draft?))
      end
    end

    private

    def linked_observations(moment)
      DuplicateObservationsForMessage.call(
        organization: @organization,
        channel_id: moment.channel_id,
        message_ts: moment.message_ts
      ).to_a
    end
  end
end
