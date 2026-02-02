class Comments::PostNotificationJob < ApplicationJob
  queue_as :default

  def perform(comment_id)
    comment = Comment.find(comment_id)
    
    # Find the root comment (if this is a nested comment, find its root)
    root_comment = comment.root_comment? ? comment : find_root_comment(comment)
    return unless root_comment
    
    company = root_comment.organization.root_company || root_comment.organization
    return unless company.maap_object_comment_channel_id.present?
    
    channel = company.maap_object_comment_channel
    channel_id = channel.third_party_id
    
    # Check if notification already exists
    existing_notification = root_comment.notifications
                                    .where(notification_type: 'comment_channel')
                                    .successful
                                    .first
    
    if existing_notification && existing_notification.message_id.present?
      # Update existing notification
      update_existing_message(root_comment, company, channel_id, existing_notification)
    else
      # Create new notification (only for root comments)
      return unless root_comment.root_comment?
      create_new_message(root_comment, company, channel_id)
    end
  rescue => e
    Rails.logger.error "Failed to post comment notification to Slack: #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")
    { success: false, error: e.message }
  end

  def find_root_comment(comment)
    # Traverse up the comment chain to find the root comment
    current = comment
    while current.commentable.is_a?(Comment)
      current = current.commentable
    end
    # Now current is the root comment (its commentable is Assignment/Ability/Aspiration, not Comment)
    current
  end

  private

  def create_new_message(comment, company, channel_id)
    blocks = build_message_blocks(comment, company)
    
    notification = comment.notifications.create!(
      notification_type: 'comment_channel',
      status: 'preparing_to_send',
      metadata: {
        channel: channel_id
      },
      rich_message: blocks,
      fallback_text: build_fallback_text(comment)
    )
    
    result = SlackService.new(company).post_message(notification.id)
    
    # Store slack_message_id on comment if successful
    if result[:success] && notification.reload.message_id.present?
      comment.update_column(:slack_message_id, notification.message_id)
    end
    
    result
  end

  def update_existing_message(comment, company, channel_id, existing_notification)
    blocks = build_message_blocks(comment, company)
    
    update_notification = comment.notifications.create!(
      notification_type: 'comment_channel',
      original_message: existing_notification,
      status: 'preparing_to_send',
      metadata: {
        channel: channel_id
      },
      rich_message: blocks,
      fallback_text: build_fallback_text(comment)
    )
    
    SlackService.new(company).update_message(update_notification.id)
  end

  def build_message_blocks(comment, company)
    root_commentable = comment.root_commentable
    commentable_name = root_commentable.respond_to?(:title) ? root_commentable.title : root_commentable.respond_to?(:name) ? root_commentable.name : root_commentable.class.name
    commentable_type = root_commentable.class.name
    
    # Build commentable link
    commentable_url = case root_commentable
    when Assignment
      Rails.application.routes.url_helpers.organization_assignment_url(company, root_commentable)
    when Ability
      Rails.application.routes.url_helpers.organization_ability_url(company, root_commentable)
    when Aspiration
      Rails.application.routes.url_helpers.organization_aspiration_url(company, root_commentable)
    else
      nil
    end
    
    # Build comments page link
    comments_url = Rails.application.routes.url_helpers.organization_comments_url(
      company,
      commentable_type: commentable_type,
      commentable_id: root_commentable.id
    )
    
    # Get creator info
    creator_name = comment.creator.display_name
    creator_teammate = company.teammates.find_by(person: comment.creator)
    creator_slack_identity = creator_teammate&.teammate_identities&.find { |ti| ti.provider == 'slack' }
    creator_slack_id = creator_slack_identity&.uid
    creator_mention = creator_slack_id.present? ? "<@#{creator_slack_id}>" : creator_name
    
    # Build main text
    commentable_link = commentable_url ? "<#{commentable_url}|#{commentable_name}>" : commentable_name
    main_text = "*New comment on #{commentable_type} #{commentable_link}*\n\n"
    main_text += "Started by #{creator_mention}"
    
    # Add comment body/content
    comment_body = comment.body
    # Truncate if too long (Slack has limits)
    if comment_body.length > 500
      comment_body = comment_body[0, 500] + "..."
    end
    main_text += "\n\n#{comment_body}"
    
    # Add last threaded comment info if there are replies
    last_threaded_comment = comment.descendants.ordered.last
    if last_threaded_comment
      last_creator_name = last_threaded_comment.creator.display_name
      last_creator_teammate = company.teammates.find_by(person: last_threaded_comment.creator)
      last_creator_slack_identity = last_creator_teammate&.teammate_identities&.find { |ti| ti.provider == 'slack' }
      last_creator_slack_id = last_creator_slack_identity&.uid
      last_creator_mention = last_creator_slack_id.present? ? "<@#{last_creator_slack_id}>" : last_creator_name
      
      # Use actual date/time in the creator's timezone instead of relative time since Slack messages don't update automatically
      creator_timezone = last_threaded_comment.creator.timezone_or_default
      last_reply_time = last_threaded_comment.created_at.in_time_zone(creator_timezone).strftime('%B %d, %Y at %l:%M %p %Z')
      main_text += "\n\n_Last reply by #{last_creator_mention} on #{last_reply_time}_"
    end
    
    # Add link to comments page
    main_text += "\n\n<#{comments_url}|View all comments>"
    
    blocks = []
    
    # If resolved, add a prominent resolved indicator at the top
    if comment.resolved?
      # Use the resolver's timezone (creator of the comment)
      resolver_timezone = comment.creator.timezone_or_default
      resolved_date = comment.resolved_at.in_time_zone(resolver_timezone).strftime('%B %d, %Y at %l:%M %p %Z')
      blocks << {
        type: "context",
        elements: [
          {
            type: "mrkdwn",
            text: "✅ *RESOLVED* on #{resolved_date}"
          }
        ]
      }
      blocks << {
        type: "divider"
      }
      
      # Apply strikethrough to all lines with text in main_text
      main_text = apply_strikethrough_to_lines(main_text)
    end
    
    # Main message content
    blocks << {
      type: "section",
      text: {
        type: "mrkdwn",
        text: truncate_slack_text(main_text)
      }
    }
    
    blocks
  end

  def build_fallback_text(comment)
    root_commentable = comment.root_commentable
    commentable_name = root_commentable.respond_to?(:title) ? root_commentable.title : root_commentable.respond_to?(:name) ? root_commentable.name : root_commentable.class.name
    "New comment on #{root_commentable.class.name} #{commentable_name} by #{comment.creator.display_name}"
  end

  def truncate_slack_text(text, max_length: 3000)
    return text if text.length <= max_length
    
    truncated = text[0, max_length]
    last_space = truncated.rindex(/\s/)
    if last_space && last_space > max_length - 100
      truncated = text[0, last_space]
    end
    
    "#{truncated}..."
  end

  def apply_strikethrough_to_lines(text)
    # Split by newlines and apply strikethrough to each line that has text
    lines = text.split("\n")
    lines.map do |line|
      # Only apply strikethrough to lines that have non-whitespace content
      if line.strip.present?
        "~#{line}~"
      else
        line
      end
    end.join("\n")
  end

  def time_ago_in_words(time)
    seconds = Time.current - time
    case seconds
    when 0..59
      "#{seconds.to_i} seconds"
    when 60..3599
      "#{(seconds / 60).to_i} minutes"
    when 3600..86399
      "#{(seconds / 3600).to_i} hours"
    when 86400..2591999
      "#{(seconds / 86400).to_i} days"
    else
      "#{(seconds / 2592000).to_i} months"
    end
  end
end
