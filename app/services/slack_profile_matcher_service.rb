class SlackProfileMatcherService
  def call(organization)
    return { success: false, error: "Organization is missing" } unless organization.present?
    
    slack_config = organization.calculated_slack_config
    return { success: false, error: "Slack not configured for this organization" } unless slack_config.present?
    
    slack_service = SlackService.new(organization)
    slack_users = slack_service.list_users
    
    return { success: false, error: "Failed to fetch Slack users" } if slack_users.empty?
    
    # Get active teammates for this organization
    active_teammates = organization.teammates
                                    .joins(:person)
                                    .where(last_terminated_at: nil)
                                    .includes(:person, :teammate_identities)
    
    matched_count = 0
    errors = []
    
    active_teammates.each do |teammate|
      person = teammate.person
      
      # Skip if teammate already has a Slack identity (preserve existing associations)
      if teammate.teammate_identities.where(provider: 'slack').exists?
        Rails.logger.info "Slack: Skipping #{person.email} - already has Slack identity"
        next
      end
      
      # Try to find matching Slack user by email (case-insensitive)
      slack_user = slack_users.find do |user|
        user_email = user.dig('profile', 'email')&.downcase
        person_email = person.email&.downcase
        user_email.present? && person_email.present? && user_email == person_email
      end
      
      next unless slack_user
      
      begin
        slack_user_id = slack_user['id']
        slack_name = slack_user.dig('profile', 'real_name') || slack_user.dig('profile', 'display_name') || slack_user['name']
        slack_email = slack_user.dig('profile', 'email')
        slack_image_url = slack_user.dig('profile', 'image_512') || 
                         slack_user.dig('profile', 'image_192') || 
                         slack_user.dig('profile', 'image_72') ||
                         slack_user.dig('profile', 'image_48') ||
                         slack_user.dig('profile', 'image_32') ||
                         slack_user.dig('profile', 'image_24')
        
        # Create new TeammateIdentity (never update existing ones)
        identity = teammate.teammate_identities.build(provider: 'slack', uid: slack_user_id)
        identity.email = slack_email
        identity.name = slack_name
        identity.profile_image_url = slack_image_url
        identity.raw_data = slack_user
        
        if identity.save
          matched_count += 1
          Rails.logger.info "Slack: Matched #{person.email} to Slack user #{slack_user_id}"
        else
          errors << "Failed to save identity for #{person.email}: #{identity.errors.full_messages.join(', ')}"
        end
      rescue => e
        errors << "Error processing #{person.email}: #{e.message}"
        Rails.logger.error "Slack: Error matching #{person.email}: #{e.message}"
      end
    end
    
    {
      success: true,
      matched_count: matched_count,
      total_teammates: active_teammates.count,
      errors: errors
    }
  rescue => e
    Rails.logger.error "Slack: Error in SlackProfileMatcherService: #{e.message}"
    { success: false, error: e.message }
  end
end


