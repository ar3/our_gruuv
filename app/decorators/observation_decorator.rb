class ObservationDecorator < Draper::Decorator
  delegate_all

  def permalink_url
    date_part = observed_at.strftime('%Y-%m-%d')
    Rails.application.routes.url_helpers.kudos_url(date: date_part, id: id)
  end
  
  def permalink_path
    date_part = observed_at.strftime('%Y-%m-%d')
    Rails.application.routes.url_helpers.kudos_path(date: date_part, id: id)
  end

  def visibility_text
    case privacy_level
    when 'observer_only'
      'Private Journal Entry'
    when 'observed_only'
      '1-on-1 Feedback'
    when 'managers_only'
      'Manager Review'
    when 'observed_and_managers'
      'Team Feedback'
    when 'public_observation'
      'Public Recognition'
    end
  end

  def visibility_icon
    case privacy_level
    when 'observer_only'
      '🔒'
    when 'observed_only'
      '👤'
    when 'managers_only'
      '👔'
    when 'observed_and_managers'
      '👥'
    when 'public_observation'
      '🌍'
    end
  end

  def visibility_text_style
    case privacy_level
    when 'observer_only'
      'Journal'
    when 'observed_only'
      '1-on-1'
    when 'managers_only'
      'Managers'
    when 'observed_and_managers'
      'Team'
    when 'public_observation'
      'Public'
    end
  end

  def feelings_display_html
    return '' if primary_feeling.blank?
    
    primary_feeling_data = Feelings.hydrate(primary_feeling)
    return '' unless primary_feeling_data
    
    html = primary_feeling_data[:display]
    
    if secondary_feeling.present?
      secondary_feeling_data = Feelings.hydrate(secondary_feeling)
      if secondary_feeling_data
        html += " #{secondary_feeling_data[:display]}"
      end
    end
    
    html
  end

  def story_html
    # Simple markdown rendering - can be enhanced later
    story.gsub(/\*\*(.*?)\*\*/, '<strong>\1</strong>')
         .gsub(/\*(.*?)\*/, '<em>\1</em>')
         .gsub(/\n/, '<br>')
  end

  def timeframe
    days_ago = (Time.current - observed_at).to_i / 1.day
    
    case days_ago
    when 0
      :this_day
    when 1..7
      :this_week
    when 8..21
      :past_three_weeks
    when 22..90
      :past_three_months
    else
      :older
    end
  end

  def channel_posts_summary
    successful_notifications = notifications.where(status: 'sent_successfully')
    channel_posts = successful_notifications.where(notification_type: 'observation_channel')
    
    return '' if channel_posts.empty?
    
    count = channel_posts.count
    count == 1 ? 'Posted to 1 channel' : "Posted to #{count} channels"
  end

  def status_markup
    parts = []
    
    # Privacy level
    parts << "#{visibility_icon} #{visibility_text_style}"
    
    # Posting status
    if posted_to_slack?
      parts << "📤 Posted"
    else
      parts << "📝 Draft"
    end
    
    parts.join(' • ')
  end
end
