module SeatsHelper
  def seat_state_badge_class(state)
    case state.to_s
    when 'draft'
      'bg-secondary'
    when 'open'
      'bg-success'
    when 'filled'
      'bg-primary'
    when 'archived'
      'bg-dark'
    else
      'bg-secondary'
    end
  end

  def seat_state_description(state)
    case state.to_s
    when 'draft'
      'Draft - Not ready for hiring'
    when 'open'
      'Open - Actively seeking candidates'
    when 'filled'
      'Filled - Position occupied'
    when 'archived'
      'Archived - No longer needed'
    else
      'Unknown state'
    end
  end
end
