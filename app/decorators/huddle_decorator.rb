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
end 