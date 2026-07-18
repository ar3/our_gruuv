# frozen_string_literal: true

module CheckIns
  module SlackOgoConsult
    # JSON payload for progressive check-in Consult OG polling.
    class StatusBuilder
      def self.call(...)
        new(...).call
      end

      def initialize(search:, rateable_type:, rateable_id:, organization:, subject_teammate:, object_name:, helpers:)
        @search = search
        @rateable_type = rateable_type
        @rateable_id = rateable_id
        @organization = organization
        @subject_teammate = subject_teammate
        @object_name = object_name
        @helpers = helpers
      end

      def call
        batches = @search.message_batches.in_position_order.to_a
        filtered = CandidateFilter.call(
          search: @search,
          rateable_type: @rateable_type,
          rateable_id: @rateable_id
        )
        phase = derive_phase(batches)
        stronger_id = Llm::SlackMomentsExtractor.stronger_model_id
        latest_consultations = batches.filter_map { |batch| latest_consultation(batch) }
        latest_models = latest_consultations.filter_map(&:model_id)
        used_stronger = latest_models.any? { |mid| mid == stronger_id }
        all_stronger = latest_models.any? && latest_models.all? { |mid| mid == stronger_id }
        any_completed_extract = batches.any? { |b| b.extraction_status == "completed" }
        latest_consult_at = latest_consultations.map(&:created_at).max

        {
          search_id: @search.id,
          phase: phase,
          search_status: @search.search_status,
          search_error: @search.search_error,
          messages_count_summary: @search.search_status == "completed" ? @search.messages_count_summary : nil,
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
          can_stronger_model: any_completed_extract && !all_stronger,
          used_stronger_model: used_stronger,
          consultation_stale: consultation_stale?(latest_consult_at),
          stale_warning: stale_warning(latest_consult_at),
          polling: %w[searching extracting].include?(phase)
        }
      end

      private

      def can_refresh_search?(latest_consult_at)
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
        item = match.item
        {
          id: item[:id],
          confidence: item[:confidence].to_f,
          confidence_pct: (item[:confidence].to_f * 100).round,
          kind: item[:kind],
          quote_preview: item[:quote].to_s.truncate(280),
          short_quote: item[:short_quote].presence || item[:full_quote].to_s.truncate(160),
          permalink: item[:permalink],
          batch_id: match.batch.id,
          batch_url: batch_url(match.batch)
        }
      end

      def empty_object_message(phase, filtered)
        return nil unless phase == "completed"
        return nil if filtered[:object_matches].any?

        casual = @subject_teammate.person.casual_name
        "No missing OGOs for #{casual} and #{@object_name} found"
      end

      def other_message(count)
        "Found #{count} other potential OGOs for other Assignments, Abilities, and Values"
      end

      def full_results_url
        @helpers.organization_company_teammate_possible_observation_slack_search_path(
          @organization,
          @subject_teammate,
          @search
        )
      end

      def batch_url(batch)
        @helpers.organization_company_teammate_possible_observation_slack_search_batch_path(
          @organization,
          @subject_teammate,
          @search,
          batch
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
