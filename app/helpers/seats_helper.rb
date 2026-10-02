module SeatsHelper
  STATE_QUICK_FILTER_CUSTOM_TOOLTIP =
    "Status must be set in Customize View".freeze

  # :all / :filled / :unfilled / :all_open / :draft when filters match a neat preset; :custom otherwise.
  # Unfilled = open only. All Open = open + filled (active seats; excludes draft/archived).
  def seat_state_quick_filter_selection(filters)
    states = Array(filters && filters[:state]).map(&:to_s).reject(&:blank?).uniq.sort
    return :all if states.empty?
    return :filled if states == %w[filled]
    return :unfilled if states == %w[open]
    return :all_open if states == %w[filled open]
    return :draft if states == %w[draft]

    :custom
  end

  def seat_state_quick_filter_path(organization, selection)
    path_params = params.except(
      :controller, :action, :page, :state, :organization_id, :id
    ).permit!.to_h

    case selection.to_sym
    when :filled
      path_params[:state] = %w[filled]
    when :unfilled
      path_params[:state] = %w[open]
    when :all_open
      path_params[:state] = %w[open filled]
    when :draft
      path_params[:state] = %w[draft]
    when :all
      path_params.delete("state")
      path_params.delete(:state)
    else
      raise ArgumentError, "Unknown seat state quick filter selection: #{selection}"
    end

    organization_seats_path(organization, path_params)
  end

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

  def open_seat_maap_proposals_count(seat)
    seat.maap_proposals.open_proposals.count
  end

  def all_proposed_seat_edits_label(seat)
    "All proposed edits (#{open_seat_maap_proposals_count(seat)})"
  end

  # Department-grouped seat options for reports-to selects.
  # Label: "Status · Seat name" and, when filled, " (casual name)".
  # Callers typically pass other seats in the org; the currently selected seat is
  # always included even when otherwise filtered out so the existing value remains selectable.
  def seats_grouped_options_for_select(organization, seats:, selected_seat_id: nil)
    seats_list = Array(seats).dup
    if selected_seat_id.present? && seats_list.none? { |seat| seat.id.to_s == selected_seat_id.to_s }
      selected = Seat.for_organization(organization)
                     .includes(:title, employment_tenures: { company_teammate: :person })
                     .find_by(id: selected_seat_id)
      seats_list << selected if selected
    end

    return "" if seats_list.blank?

    seats_by_department = seats_list.group_by { |seat| seat.title&.department }
    ordered_keys = seats_by_department.keys.sort_by { |dept| dept ? [1, dept.display_name.to_s.downcase] : [0, ""] }

    grouped_options = ordered_keys.map do |department|
      label =
        if department
          department_hierarchy_display(department).presence || department.display_name
        else
          "Company-wide"
        end
      choices = seats_by_department[department]
                .sort_by { |seat| [seat.state.to_s, seat.display_name.to_s.downcase] }
                .map { |seat| seat_select_option(seat) }
      [label, choices]
    end

    grouped_options_for_select(grouped_options, selected_seat_id)
  end

  def seat_select_option(seat)
    label = "#{seat.state.titleize} · #{seat.display_name}"
    person = seat.employment_tenures.find { |tenure| tenure.ended_at.nil? }&.teammate&.person
    label = "#{label} (#{person.casual_name})" if person&.casual_name.present?
    [label, seat.id]
  end

  def seat_select_label(seat)
    seat_select_option(seat).first
  end
end
