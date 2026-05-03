# frozen_string_literal: true

class BulkSyncEvent::UploadAbilitiesHrReview < BulkSyncEvent
  def self.mark_completed_if_done!(event)
    return unless event.is_a?(BulkSyncEvent::UploadAbilitiesHrReview)

    rows = Array(event.preview_actions&.dig('rows'))
    return if rows.empty?
    return unless event.preview?

    terminal = rows.all? { |r| %w[applied skipped failed].include?(r['state'].to_s) }
    return unless terminal

    existing = event.results.is_a?(Hash) ? event.results.deep_stringify_keys : {}
    existing['successes'] ||= []
    existing['failures'] ||= []
    existing['summary'] = {
      'applied' => rows.count { |r| r['state'] == 'applied' },
      'skipped' => rows.count { |r| r['state'] == 'skipped' },
      'failed' => rows.count { |r| r['state'] == 'failed' }
    }
    event.update!(status: :completed, results: existing)
  end

  def validate_file_type(file)
    file.content_type.in?(['text/csv', 'application/csv']) || file.original_filename.to_s.end_with?('.csv')
  end

  def process_file_for_preview
    built = AbilitiesHrReview::BuildPreview.call(
      file_content: source_contents,
      organization: organization
    )

    preview = (built[:preview_actions] || {}).stringify_keys.merge('parse_ok' => built[:ok])
    update!(
      preview_actions: preview,
      attempted_at: Time.current
    )

    if built[:ok]
      AbilitiesHrReviewEnrichmentJob.perform_later(id)
    end

    true
  end

  def process_upload_in_background
    # Row-by-row approval only; no bulk processor job.
    true
  end

  def display_name
    'HR abilities CSV (review)'
  end

  def file_extension
    'csv'
  end

  def parse_error_message
    nil
  end

  def process_file_content_for_storage(file)
    file.read
  end
end
