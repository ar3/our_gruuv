class SlackChannelsService
  def initialize(organization)
    @organization = organization
  end

  def refresh_channels
    Rails.logger.info "SlackChannelsService: Starting refresh for organization #{@organization.id}"
    return false unless @organization.slack_configured?

    Rails.logger.info "SlackChannelsService: Organization has Slack configured"
    slack_service = SlackService.new(@organization)

    begin
      # Get all channels the bot has access to
      Rails.logger.info "SlackChannelsService: Calling SlackService.list_channels"
      response = slack_service.list_channels
      Rails.logger.info "SlackChannelsService: Got response: #{response.class} with #{response&.length || 0} channels"

      if response.is_a?(Array) && response.any?
        Rails.logger.info "SlackChannelsService: Updating channels cache with #{response.length} channels"
        update_channels_cache(response)
        Rails.logger.info "SlackChannelsService: Successfully updated channels cache"
        true
      else
        Rails.logger.error "SlackChannelsService: Failed to fetch Slack channels or no channels returned"
        false
      end
    rescue => e
      Rails.logger.error "SlackChannelsService: Error refreshing Slack channels: #{e.message}"
      Rails.logger.error "SlackChannelsService: Backtrace: #{e.backtrace.first(5).join("\n")}"
      false
    end
  end

  private

  def update_channels_cache(channels)
    Rails.logger.info "SlackChannelsService: Starting update_channels_cache with #{channels.length} channels"
    
    # Mark all existing channels as deleted first
    deleted_count = @organization.third_party_objects.slack_channels.update_all(deleted_at: Time.current)
    Rails.logger.info "SlackChannelsService: Marked #{deleted_count} existing channels as deleted"

    channels.each do |channel|
      Rails.logger.info "SlackChannelsService: Processing channel: #{channel.inspect}"
      
      # Find or create the channel record
      channel_record = @organization.third_party_objects.slack_channels
                                   .with_deleted
                                   .find_or_initialize_by(third_party_id: channel['id'])

      # Update the record
      channel_record.assign_attributes(
        display_name: channel['name'],
        third_party_name: channel['name'],
        third_party_object_type: 'channel',
        third_party_source: 'slack',
        deleted_at: nil
      )

      if channel_record.save!
        Rails.logger.info "SlackChannelsService: Saved channel #{channel['name']} (ID: #{channel['id']})"
      else
        Rails.logger.error "SlackChannelsService: Failed to save channel #{channel['name']}: #{channel_record.errors.full_messages}"
      end
    end
    
    Rails.logger.info "SlackChannelsService: Finished update_channels_cache"
  end
end 