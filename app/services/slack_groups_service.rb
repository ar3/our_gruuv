class SlackGroupsService
  def initialize(organization)
    @organization = organization
  end

  def refresh_groups
    Rails.logger.info "SlackGroupsService: Starting refresh for organization #{@organization.id}"
    return false unless @organization.slack_configured?

    Rails.logger.info "SlackGroupsService: Organization has Slack configured"
    slack_service = SlackService.new(@organization)

    begin
      # Get all groups the bot has access to
      Rails.logger.info "SlackGroupsService: Calling SlackService.list_groups"
      response = slack_service.list_groups
      Rails.logger.info "SlackGroupsService: Got response: #{response.class} with #{response&.length || 0} groups"

      if response.is_a?(Array) && response.any?
        Rails.logger.info "SlackGroupsService: Updating groups cache with #{response.length} groups"
        update_groups_cache(response)
        Rails.logger.info "SlackGroupsService: Successfully updated groups cache"
        true
      else
        Rails.logger.error "SlackGroupsService: Failed to fetch Slack groups or no groups returned"
        false
      end
    rescue => e
      Rails.logger.error "SlackGroupsService: Error refreshing Slack groups: #{e.message}"
      Rails.logger.error "SlackGroupsService: Backtrace: #{e.backtrace.first(5).join("\n")}"
      false
    end
  end

  private

  def update_groups_cache(groups)
    Rails.logger.info "SlackGroupsService: Starting update_groups_cache with #{groups.length} groups"
    
    # Mark all existing groups as deleted first
    deleted_count = @organization.third_party_objects
                                  .where(third_party_source: 'slack', third_party_object_type: 'group')
                                  .update_all(deleted_at: Time.current)
    Rails.logger.info "SlackGroupsService: Marked #{deleted_count} existing groups as deleted"

    groups.each do |group|
      Rails.logger.info "SlackGroupsService: Processing group: #{group.inspect}"
      
      # Find or create the group record
      group_record = @organization.third_party_objects
                                  .where(third_party_source: 'slack', third_party_object_type: 'group')
                                  .with_deleted
                                  .find_or_initialize_by(third_party_id: group['id'])

      # Update the record
      group_record.assign_attributes(
        display_name: group['name'] || group['handle'] || group['id'],
        third_party_name: group['name'] || group['handle'] || group['id'],
        third_party_object_type: 'group',
        third_party_source: 'slack',
        deleted_at: nil
      )

      if group_record.save!
        Rails.logger.info "SlackGroupsService: Saved group #{group_record.display_name} (ID: #{group['id']})"
      else
        Rails.logger.error "SlackGroupsService: Failed to save group #{group['name']}: #{group_record.errors.full_messages}"
      end
    end
    
    Rails.logger.info "SlackGroupsService: Finished update_groups_cache"
  end
end

