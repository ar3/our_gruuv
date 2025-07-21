module ApplicationHelper
  def format_time_in_user_timezone(time, user = nil)
    user ||= current_person if respond_to?(:current_person)
    return time.strftime('%B %d, %Y at %I:%M %p %Z') unless user&.timezone.present?
    
    time.in_time_zone(user.timezone).strftime('%B %d, %Y at %I:%M %p %Z')
  end
  
  def available_timezones
    ActiveSupport::TimeZone.all.map { |tz| [tz.name, tz.name] }
  end

  # Make policy available in views
  def policy(record)
    user = current_person if respond_to?(:current_person)
    user ||= @current_person if defined?(@current_person)
    Pundit.policy(user, record)
  end
end
