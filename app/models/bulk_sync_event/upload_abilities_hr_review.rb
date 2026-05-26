# frozen_string_literal: true

class BulkSyncEvent::UploadAbilitiesHrReview < BulkSyncEvent
  TERMINAL_ROW_STATES = %w[applied skipped failed invalid].freeze

  def self.mark_completed_if_done!(event)
    return unless event.is_a?(BulkSyncEvent::UploadAbilitiesHrReview)
    return unless event.preview?

    preview = event.preview_actions.is_a?(Hash) ? event.preview_actions.deep_stringify_keys : {}
    groups = Array(preview['ability_groups'])
    associations = Array(preview['association_rows'])

    return if groups.empty?

    return unless groups.all? { |g| TERMINAL_ROW_STATES.include?(g['state'].to_s) }
    return if groups.any? { |g| g['state'].to_s == 'pending' }
    return if associations.any? { |a| a['state'].to_s == 'pending' }

    existing = event.results.is_a?(Hash) ? event.results.deep_stringify_keys : {}
    existing['successes'] ||= []
    existing['failures'] ||= []
    existing['summary'] = {
      'abilities_applied' => groups.count { |g| g['state'] == 'applied' },
      'abilities_skipped' => groups.count { |g| g['state'] == 'skipped' },
      'abilities_invalid' => groups.count { |g| g['state'] == 'invalid' },
      'associations_applied' => associations.count { |a| a['state'] == 'applied' },
      'associations_skipped' => associations.count { |a| a['state'] == 'skipped' },
      'associations_failed' => associations.count { |a| a['state'] == 'failed' }
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
      AbilitiesHrReview::EnrichPreview.call(bulk_sync_event: self)
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
