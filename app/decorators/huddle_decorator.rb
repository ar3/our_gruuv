class HuddleDecorator < Draper::Decorator
  delegate_all

  def status_with_time
    if object.closed?
      hours_ago = ((Time.current - object.expires_at) / 1.hour).round
      if hours_ago == 1
        "Inactive for 1 hour"
      else
        "Inactive for #{hours_ago} hours"
      end
    else
      hours_remaining = ((object.expires_at - Time.current) / 1.hour).round
      if hours_remaining == 1
        "Active for 1 more hour"
      else
        "Active for #{hours_remaining} more hours"
      end
    end
  end

  # Display name without company - shows team name and date
  def display_name_without_organization
    "#{object.team&.name || 'Unknown Team'} - #{object.huddle_display_day}"
  end
end 