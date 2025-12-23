module ApplicationHelper
  include HuddleConstants
  include Pagy::Frontend
  include CheckInHelper

  # Color helper methods for consistent UI
  def rating_color(rating)
    return 'secondary' unless rating
    HuddleConstants::RATING_COLORS[rating.to_i] || 'secondary'
  end

  def nat_20_color(score)
    return 'secondary' unless score
    score = score.to_f
    
    # Find the matching range in the NAT_20_COLORS constant
    HuddleConstants::NAT_20_COLORS.find { |range, color| range.include?(score) }&.last || 'secondary'
  end

  def feedback_participation_color(submitted_count, total_count)
    return 'light' if total_count.zero?
    
    percentage = (submitted_count.to_f / total_count * 100).round(0)
    
    # Find the matching range in the FEEDBACK_PARTICIPATION_COLORS constant
    HuddleConstants::FEEDBACK_PARTICIPATION_COLORS.find { |range, color| range.include?(percentage) }&.last || 'light'
  end

  def status_color(status)
    HuddleConstants::STATUS_COLORS[status.to_s.downcase] || 'secondary'
  end

  def feedback_color(type)
    HuddleConstants::FEEDBACK_COLORS[type.to_s.downcase] || 'info'
  end

  def conflict_style_color(style)
    HuddleConstants::CONFLICT_STYLE_COLORS[style] || 'secondary'
  end

  # Helper for badge classes
  def badge_class(color)
    "badge bg-#{color}"
  end

  def text_class(color)
    "text-#{color}"
  end

  # Helper for rating badges
  def rating_badge(rating, show_number = true)
    color = rating_color(rating)
    content = show_number ? rating : ''
    content_tag(:span, content, class: badge_class(color))
  end

  # Helper for Nat 20 score badges
  def nat_20_badge(score, show_number = true)
    color = nat_20_color(score)
    content = show_number ? score : ''
    content_tag(:span, content, class: badge_class(color))
  end

  # Helper for feedback participation badges
  def feedback_participation_badge(submitted_count, total_count, show_text = true)
    color = feedback_participation_color(submitted_count, total_count)
    content = show_text ? "#{submitted_count} of #{total_count}" : ''
    content_tag(:span, content, class: badge_class(color))
  end

  # Helper for status badges
  def status_badge(status, text = nil)
    color = status_color(status)
    content = text || status.to_s.titleize
    content_tag(:span, content, class: badge_class(color))
  end

  # Helper for feedback badges
  def feedback_badge(type, text = nil)
    color = feedback_color(type)
    content = text || type.to_s.titleize
    content_tag(:span, content, class: badge_class(color))
  end

  # Helper for conflict style badges
  def conflict_style_badge(style, text = nil)
    color = conflict_style_color(style)
    content = text || style
    content_tag(:span, content, class: badge_class(color))
  end

  def format_time_in_user_timezone(time, user = nil)
    user ||= current_person if respond_to?(:current_person)
    user.person ||= current_person if user.is_a?(Teammate)
    return time.in_time_zone('Eastern Time (US & Canada)').strftime('%B %d, %Y at %I:%M %p %Z') unless user&.timezone.present?
    
    time.in_time_zone(user.timezone).strftime('%B %d, %Y at %I:%M %p %Z')
  end
  
  def available_timezones
    ActiveSupport::TimeZone.all.map { |tz| [tz.name, tz.name] }
  end
  
  def potential_employee_reason(person)
    reasons = []
    if person.teammates.exists?
      reasons << "Has access permissions"
    end
    if person.huddle_participants.exists?
      reasons << "Participated in huddles"
    end
    reasons.join(", ")
  end

  # Notification debug helper methods
  def notification_type_badge_class(notification_type)
    case notification_type
    when 'huddle_announcement'
      'bg-primary'
    when 'huddle_summary'
      'bg-info'
    when 'huddle_feedback'
      'bg-success'
    when 'test'
      'bg-warning'
    else
      'bg-secondary'
    end
  end

  def status_badge_class(status)
    case status
    when 'preparing_to_send'
      'bg-warning'
    when 'sent_successfully'
      'bg-success'
    when 'send_failed'
      'bg-danger'
    else
      'bg-secondary'
    end
  end

  # Make policy available in views
  def policy(record)
    # Try to get pundit_user from controller context
    pundit_user_struct = if respond_to?(:pundit_user)
      pundit_user
    elsif defined?(@controller) && @controller.respond_to?(:pundit_user)
      @controller.pundit_user
    elsif respond_to?(:current_company_teammate) && current_company_teammate
      # Fallback: create pundit_user structure from current_company_teammate
      OpenStruct.new(user: current_company_teammate, impersonating_teammate: nil)
    else
      Raven.capture_message("ApplicationHelper: pundit_user_struct is nil, so returning current_person which will likely cause failures", level: :warning)
      # Last resort: try current_person (may not work correctly)
      current_person if respond_to?(:current_person)
    end
    Pundit.policy(pundit_user_struct, record)
  end

  # Markdown rendering helper
  def render_markdown(text)
    return '' if text.blank?
    
    # Trim whitespace to avoid extra newlines
    text = text.strip
    
    markdown = Redcarpet::Markdown.new(
      Redcarpet::Render::HTML,
      autolink: true,
      tables: true,
      fenced_code_blocks: true,
      strikethrough: true,
      superscript: true,
      underline: true,
      highlight: true,
      quote: true,
      footnotes: true
    )
    
    # Render markdown and then convert remaining newlines to <br/> tags
    rendered = markdown.render(text)
    rendered.gsub(/\n/, '<br/>').gsub(/<br\/>$/, '').html_safe
  end

  # Observation sort options helper
  def observation_sort_options
    [
      ['Most Recent', 'observed_at_desc'],
      ['Oldest First', 'observed_at_asc'],
      ['Most Ratings', 'ratings_count_desc'],
      ['Alphabetical', 'story_asc']
    ]
  end

  def privacy_level_class(privacy_level)
    case privacy_level
    when 'observer_only'
      'text-muted'
    when 'observed_only'
      'text-info'
    when 'managers_only'
      'text-warning'
    when 'observed_and_managers'
      'text-primary'
    when 'public_observation'
      'text-success'
    else
      'text-muted'
    end
  end

  # Returns "a" or "an" based on whether the word starts with a vowel sound
  def indefinite_article(word)
    return 'a' if word.blank?
    
    # Get the first letter (case-insensitive)
    first_char = word.to_s.strip[0]&.downcase
    
    # Words that start with vowel sounds use "an"
    # This handles most common cases, though not perfect (e.g., "hour", "honor")
    if %w[a e i o u].include?(first_char)
      'an'
    else
      'a'
    end
  end
end
