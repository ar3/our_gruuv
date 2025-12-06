class ObservationDecorator < Draper::Decorator
  delegate_all

  def permalink_url
    date_part = observed_at.strftime('%Y-%m-%d')
    Rails.application.routes.url_helpers.organization_kudo_url(company, date: date_part, id: id)
  end
  
  def permalink_path
    date_part = observed_at.strftime('%Y-%m-%d')
    Rails.application.routes.url_helpers.organization_kudo_path(company, date: date_part, id: id)
  end

  def visibility_text
    case privacy_level
    when 'observer_only'
      'Private Journal Entry'
    when 'observed_only'
      'Direct 1-on-1 Feedback'
    when 'managers_only'
      'Between Observer and Managers'
    when 'observed_and_managers'
      'Shared with everyone directly involved'
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

  def privacy_rings
    case privacy_level
    when 'observer_only'
      '🔘○○○'
    when 'observed_only'
      '🔘🔘○○'
    when 'managers_only'
      '🔘○🔘○'
    when 'observed_and_managers'
      '🔘🔘🔘○'
    when 'public_observation'
      '🔘🔘🔘🔘'
    end
  end

  def privacy_label
    case privacy_level
    when 'observer_only'
      'Private Journal'
    when 'observed_only'
      'Private Direct'
    when 'managers_only'
      'Manager Only'
    when 'observed_and_managers'
      'Stakeholders'
    when 'public_observation'
      'Public'
    end
  end

  def privacy_rings_with_label
    "#{privacy_rings} #{privacy_label}"
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
    html = if story.present?
      story.gsub(/\*\*(.*?)\*\*/, '<strong>\1</strong>')
           .gsub(/\*(.*?)\*/, '<em>\1</em>')
           .gsub(/\n/, '<br>')
    else
      ''
    end
    
    # Append GIFs if present
    gifs_html = self.gifs_html
    html += gifs_html if gifs_html.present?
    
    html
  end

  def gifs_html
    return '' unless story_extras.present?
    
    # Handle both hash and string keys, and ensure we have gif_urls
    gif_urls = story_extras['gif_urls'] || story_extras[:gif_urls] || []
    gif_urls = Array(gif_urls).reject(&:blank?)
    return '' if gif_urls.empty?
    
    # Wrap GIFs in Bootstrap responsive row with columns
    gif_columns = gif_urls.map do |url|
      "<div class='col-12 col-md-6 col-lg-4 mb-3'>" \
        "<div class='gif-container'>" \
          "<img src='#{ERB::Util.html_escape(url)}' alt='GIF' class='img-fluid rounded' />" \
        "</div>" \
      "</div>"
    end.join
    
    "<div class=\"row\">#{gif_columns}</div>"
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
