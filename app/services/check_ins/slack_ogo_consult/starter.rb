# frozen_string_literal: true

module CheckIns
  module SlackOgoConsult
    # Starts or re-runs Slack OGO consultation from a 1-by-1 check-in context.
    class Starter
      Result = Data.define(:ok?, :search, :error, :needs_slack_oauth)

      def self.call(...)
        new(...).call
      end

      def initialize(organization:, viewer:, subject_teammate:, mode:, existing_search: nil)
        @organization = organization
        @viewer = viewer
        @subject_teammate = subject_teammate
        @mode = mode.to_s
        @existing_search = existing_search
      end

      def call
        return Result.new(ok?: false, search: nil, error: "Connect Slack (search) first.", needs_slack_oauth: true) unless slack_connected?

        case @mode
        when "fresh", "refresh_search"
          start_new_search
        when "rerun_consultation"
          rerun_extractions(model_id: Llm::SlackMomentsExtractor.model_id)
        when "stronger_model"
          rerun_extractions(model_id: Llm::SlackMomentsExtractor.stronger_model_id)
        else
          Result.new(ok?: false, search: nil, error: "Unknown mode.", needs_slack_oauth: false)
        end
      end

      private

      def slack_connected?
        @viewer&.has_slack_search_identity?
      end

      def start_new_search
        search = PossibleObservationSlackSearch.create!(
          organization: @organization,
          creator_company_teammate: @viewer,
          subject_company_teammate: @subject_teammate,
          window_days: WINDOW_DAYS,
          display_name: default_display_name,
          search_status: "pending",
          extraction_status: "ready",
          auto_extract_after_search: true
        )
        PossibleObservationSlackSearchJob.perform_later(search.id)
        Result.new(ok?: true, search: search, error: nil, needs_slack_oauth: false)
      end

      def rerun_extractions(model_id:)
        search = @existing_search
        if search.nil? || search.search_status != "completed"
          return Result.new(ok?: false, search: nil, error: "No completed Slack search to re-run.", needs_slack_oauth: false)
        end

        batches = search.message_batches.to_a
        if batches.empty?
          return Result.new(ok?: false, search: search, error: "No consultation batches on this search.", needs_slack_oauth: false)
        end

        batches.each do |batch|
          batch.update!(extraction_status: "pending", extraction_error: nil, extractions: {})
          PossibleObservationSlackSearchExtractionJob.perform_later(batch.id, model_id: model_id)
        end
        Result.new(ok?: true, search: search, error: nil, needs_slack_oauth: false)
      end

      def default_display_name
        casual = @subject_teammate.person.casual_name
        "Slack search about #{casual} (last #{WINDOW_DAYS} days) — #{Time.current.strftime('%Y-%m-%d %H:%M')}"
      end
    end
  end
end
