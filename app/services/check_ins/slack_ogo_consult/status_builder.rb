# frozen_string_literal: true

module CheckIns
  module SlackOgoConsult
    # JSON payload for progressive check-in Consult OG polling.
    # Candidates come from durable SlackPossibleObservations; search drives phase only.
    class StatusBuilder
      def self.call(...)
        new(...).call
      end

      def initialize(search:, rateable_type:, rateable_id:, organization:, subject_teammate:, object_name:, helpers:, viewer:, since: nil, until_time: nil)
        @search = search
        @rateable_type = rateable_type
        @rateable_id = rateable_id
        @organization = organization
        @subject_teammate = subject_teammate
        @object_name = object_name
        @helpers = helpers
        @viewer = viewer
        @since = since
        @until = until_time
      end

      def call
        batches = @search ? @search.message_batches.in_position_order.to_a : []
        filtered = DurableCandidateFilter.call(
          subject: @subject_teammate,
          viewer: @viewer,
          organization: @organization,
          rateable_type: @rateable_type,
          rateable_id: @rateable_id,
          since: @since,
          until_time: @until
        )
        phase = derive_phase(batches)
        latest_consultations = batches.filter_map { |batch| latest_consultation(batch) }
        latest_consult_at = latest_consultations.map(&:created_at).max

        {
          search_id: @search&.id,
          phase: phase,
          search_status: @search&.search_status,
          search_error: @search&.search_error,
          messages_count_summary: @search&.search_status == "completed" ? @search.messages_count_summary : nil,
          batches_total: batches.size,
          batches_completed: batches.count { |b| b.extraction_status == "completed" },
          batches_failed: batches.count { |b| b.extraction_status == "failed" },
          batches_in_flight: batches.count { |b| %w[pending processing].include?(b.extraction_status) },
          batches: batches.map { |batch| batch_row(batch) },
          object_matches: filtered[:object_matches].map { |m| serialize_match(m) },
          other_count: filtered[:other_matches].size,
          empty_object_message: empty_object_message(phase, filtered),
          other_message: other_message(filtered[:other_matches].size),
          full_results_url: full_results_url,
          can_refresh_search: can_refresh_search?(latest_consult_at),
          consultation_stale: consultation_stale?(latest_consult_at),
          stale_warning: stale_warning(latest_consult_at),
          polling: %w[searching extracting].include?(phase)
        }
      end

      private

      def can_refresh_search?(latest_consult_at)
        return true if @search.nil?
        return false if latest_consult_at.blank?

        latest_consult_at < REFRESH_SEARCH_AFTER.ago
      end

      def consultation_stale?(latest_consult_at)
        return false if latest_consult_at.blank?

        latest_consult_at < STALE_AFTER.ago
      end

      def stale_warning(latest_consult_at)
        return nil unless consultation_stale?(latest_consult_at)

        "These OG consultation results may be out of date. Refresh search and consult for newer Slack moments."
      end

      def derive_phase(batches)
        return "idle" if @search.nil?

        case @search.search_status
        when "pending", "processing"
          "searching"
        when "failed"
          "failed"
        when "completed"
          if batches.empty?
            "completed"
          elsif batches.any? { |b| %w[pending processing].include?(b.extraction_status) }
            "extracting"
          elsif batches.any? { |b| b.extraction_status == "failed" } &&
                batches.none? { |b| %w[pending processing].include?(b.extraction_status) } &&
                batches.none? { |b| b.extraction_status == "completed" }
            "failed"
          else
            "completed"
          end
        else
          "idle"
        end
      end

      def batch_row(batch)
        {
          id: batch.id,
          position: batch.position,
          label: batch.display_label,
          extraction_status: batch.extraction_status,
          messages_count: batch.messages_count
        }
      end

      def serialize_match(match)
        record = match.record
        {
          id: record.id,
          slack_possible_observation_id: record.id,
          html: render_moment_row(match)
        }
      end

      def render_moment_row(match)
        ApplicationController.render(
          partial: "organizations/company_teammates/slack_possible_observations/moment_row",
          locals: {
            moment: match.record,
            draft_observation: match.draft_observation,
            teammate: @subject_teammate,
            actions: :evidence
          }
        )
      end

      def empty_object_message(phase, filtered)
        return nil unless %w[completed idle].include?(phase)
        return nil if filtered[:object_matches].any?

        casual = @subject_teammate.person.casual_name
        "No missing OGOs for #{casual} and #{@object_name} found"
      end

      def other_message(count)
        "Found #{count} other potential OGOs for other Assignments, Abilities, and Values"
      end

      def full_results_url
        moments_url
      end

      def moments_url
        @helpers.ogos_source_from_slack_organization_company_teammate_path(
          @organization,
          @subject_teammate
        )
      end

      def latest_consultation(batch)
        OgConsultation.latest_for(
          subject: batch,
          kind: OgConsultation::KIND_OGO_SEARCH_SLACK
        )
      end
    end
  end
end
