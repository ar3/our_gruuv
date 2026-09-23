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

  # Department-grouped seat options with status in the label.
  # Callers typically pass non-filled seats; the currently selected seat is
  # always included even when filled so the existing value remains selectable.
  def seats_grouped_options_for_select(organization, seats:, selected_seat_id: nil)
    seats_list = Array(seats).dup
    if selected_seat_id.present? && seats_list.none? { |seat| seat.id.to_s == selected_seat_id.to_s }
      selected = organization.seats.includes(title: :department).find_by(id: selected_seat_id)
      seats_list << selected if selected
    end

    return '' if seats_list.blank?

    seats_by_department = seats_list.group_by { |seat| seat.title&.department || organization }
    company_wide = seats_by_department.keys.find { |key| key.is_a?(Organization) }
    departments = seats_by_department.keys.select { |key| key.is_a?(Department) }.sort_by(&:display_name)

    grouped_options = []

    if company_wide && seats_by_department[company_wide].any?
      grouped_options << [
        company_wide.display_name,
        seats_by_department[company_wide].map { |seat| seat_select_option(seat) }
      ]
    end

    departments.each do |department|
      next if seats_by_department[department].blank?

      grouped_options << [
        department.display_name,
        seats_by_department[department].map { |seat| seat_select_option(seat) }
      ]
    end

    grouped_options_for_select(grouped_options, selected_seat_id)
  end

  def seat_select_option(seat)
    ["#{seat.display_name} (#{seat.state.titleize})", seat.id]
  end

  def seat_select_label(seat)
    seat_select_option(seat).first
  end
end
