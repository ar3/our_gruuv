class SeatsQuery
  attr_reader :organization, :params

  def initialize(organization, params = {})
    @organization = organization
    @params = params
  end

  def call
    seats = base_scope
    seats = filter_by_state(seats)
    seats = filter_by_has_direct_reports(seats)
    seats = apply_sort(seats)
    seats.distinct
  end

  def current_filters
    filters = {}
    filters[:state] = Array(params[:state]) if params[:state].present?
    filters[:has_direct_reports] = params[:has_direct_reports] if params[:has_direct_reports].present?
    filters
  end

  def current_sort
    params[:sort] || 'seat_needed_by'
  end

  def current_view
    return params[:view] if params[:view].present?
    'table' # Default to table view
  end

  def has_active_filters?
    current_filters.any?
  end

  private

  def base_scope
    Seat.for_organization(organization)
        .includes(:title, :reports_to_seat, :reporting_seats, employment_tenures: { teammate: :person })
  end

  def filter_by_state(seats)
    return seats unless params[:state].present?

    states = Array(params[:state])
    return seats if states.empty?

    seats.where(state: states)
  end

  def filter_by_has_direct_reports(seats)
    return seats unless params[:has_direct_reports].present?

    case params[:has_direct_reports].to_s
    when 'true'
      # Seats that have at least one reporting seat
      seats.where(id: Seat.select(:reports_to_seat_id).where.not(reports_to_seat_id: nil))
    when 'false'
      # Seats that have no reporting seats
      seats.where.not(id: Seat.select(:reports_to_seat_id).where.not(reports_to_seat_id: nil))
    else
      seats
    end
  end

  def apply_sort(seats)
    case params[:sort]
    when 'title'
      seats.joins(:title).order('titles.external_title ASC, seats.seat_needed_by ASC')
    when 'title_desc'
      seats.joins(:title).order('titles.external_title DESC, seats.seat_needed_by DESC')
    when 'seat_needed_by_desc'
      seats.order(seat_needed_by: :desc)
    when 'state'
      seats.order(state: :asc, seat_needed_by: :asc)
    when 'created_at'
      seats.order(created_at: :desc)
    when 'created_at_asc'
      seats.order(created_at: :asc)
    else # 'seat_needed_by' or default
      seats.order(seat_needed_by: :asc)
    end
  end
end

