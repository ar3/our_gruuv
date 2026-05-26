# frozen_string_literal: true

module AbilitiesHrReview
  # Applies or skips all pending association rows from one Step 2 form submission.
  class ProcessAssociationRows
    def self.call(bulk_sync_event:, person:, submissions:)
      new(bulk_sync_event: bulk_sync_event, person: person, submissions: submissions).call
    end

    def initialize(bulk_sync_event:, person:, submissions:)
      @event = bulk_sync_event
      @person = person
      @submissions = normalize_submissions(submissions)
    end

    def call
      unless @event.is_a?(BulkSyncEvent::UploadAbilitiesHrReview)
        return Result.err('Invalid bulk sync event type')
      end

      return Result.err('No associations to process') if @submissions.empty?

      errors = []

      @submissions.each do |submission|
        row_id = submission['association_row_id'].to_s
        action = submission['action'].to_s

        result =
          case action
          when 'skip'
            SkipAssociationRow.call(bulk_sync_event: @event.reload, association_row_id: row_id)
          when 'apply'
            ApproveAssociationRow.call(
              bulk_sync_event: @event.reload,
              association_row_id: row_id,
              person: @person,
              overrides: submission.slice('resolved_assignment_id', 'join_milestone_level')
            )
          else
            Result.err("Unknown action for row #{row_id}")
          end

        errors << "#{row_label(row_id)}: #{result.error}" unless result.ok?
      end

      return Result.err(errors.join('; ')) if errors.any?

      Result.ok(true)
    end

    private

    def normalize_submissions(submissions)
      Array(submissions).filter_map do |entry|
        h = entry.is_a?(Hash) ? entry.stringify_keys : {}
        row_id = h['association_row_id'].to_s
        next if row_id.blank?

        h.slice('association_row_id', 'action', 'resolved_assignment_id', 'join_milestone_level')
      end
    end

    def row_label(row_id)
      preview = @event.preview_actions.is_a?(Hash) ? @event.preview_actions.deep_stringify_keys : {}
      row = Array(preview['association_rows']).find { |r| r['id'].to_s == row_id }
      row&.dig('assignment_raw').presence || row_id
    end
  end
end
