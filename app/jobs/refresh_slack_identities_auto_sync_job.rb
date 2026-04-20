class RefreshSlackIdentitiesAutoSyncJob < ApplicationJob
  queue_as :default

  def perform(organization_id, creator_id = nil, initiator_id = nil, run_mode = 'daily')
    organization = Organization.find(organization_id)
    return false unless organization.slack_configured?

    bulk_sync_event = organization.bulk_sync_events.create!(
      type: 'BulkSyncEvent::RefreshSlackSync',
      status: 'processing',
      creator_id: creator_id,
      initiator_id: initiator_id,
      source_data: {
        type: 'slack_sync',
        sync_mode: run_mode,
        auto_run: true,
        fetched_at: Time.current.iso8601
      }
    )

    parser = RefreshSlackSyncParser.new(organization)
    unless parser.parse
      bulk_sync_event.mark_as_failed!("Parsing failed: #{parser.errors.join(', ')}")
      return false
    end

    preview_actions = parser.enhanced_preview_actions.except('suggest_terminations')
    bulk_sync_event.update!(
      source_contents: parser.raw_slack_response.to_json,
      source_data: {
        type: 'slack_sync',
        sync_mode: run_mode,
        auto_run: true,
        workspace_id: parser.workspace_id,
        workspace_name: parser.workspace_name,
        total_users_fetched: parser.total_users_fetched,
        fetched_at: Time.current.iso8601
      },
      preview_actions: preview_actions
    )

    processor = RefreshSlackSyncProcessor.new(bulk_sync_event, organization, fail_on_no_actions: false)

    if processor.process
      bulk_sync_event.mark_as_completed!(processor.results)
      true
    else
      error_message = "Processing failed: #{processor.results[:failures].map { |f| f[:error] }.compact.join(', ')}"
      bulk_sync_event.mark_as_failed!(error_message)
      false
    end
  rescue => e
    bulk_sync_event&.mark_as_failed!("Unexpected error: #{e.message}")
    Rails.logger.error "RefreshSlackIdentitiesAutoSyncJob failed for organization #{organization_id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    false
  end
end
