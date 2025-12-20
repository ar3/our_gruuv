class Organizations::SeatsController < Organizations::OrganizationNamespaceBaseController
  before_action :set_seat, only: [:show, :edit, :update, :destroy, :reconcile]
  before_action :set_related_data, only: [:new, :edit, :create, :update]

  def index
    authorize company, :view_seats?
    
    # Handle preset application (if preset is selected and no discrete options changed)
    apply_preset_if_selected
    
    # Use SeatsQuery for filtering and sorting
    query = SeatsQuery.new(organization, params)
    
    # Get filtered seats
    filtered_seats = policy_scope(query.call)
    
    # Handle hierarchy view
    if query.current_view == 'seat_hierarchy'
      # Build hierarchy tree
      hierarchy_query = SeatHierarchyQuery.new(organization: organization)
      full_hierarchy_tree = hierarchy_query.call
      
      # Apply filters to hierarchy tree
      filtered_seat_ids = filtered_seats.map(&:id).to_set
      @hierarchy_tree = filter_hierarchy_tree(full_hierarchy_tree, filtered_seat_ids)
      
      # Find unassigned seats (seats with no parent) matching filters
      @unassigned_seats = filtered_seats.select { |seat| seat.reports_to_seat_id.nil? }
      
      @filtered_seats = filtered_seats.to_a
    else
      # For other views, use filtered seats directly
      @filtered_seats = filtered_seats.to_a
      
      # For seat_maap_health view, group by position type
      if query.current_view == 'seat_maap_health'
        @seats_by_position_type = @filtered_seats.group_by(&:position_type)
        @position_types = @seats_by_position_type.keys.sort_by(&:external_title)
        
        # Preload maturity data for all position types
        @position_types.each do |position_type|
          position_type.maap_maturity_phase
        end
      end
    end
    
    # Store current filter/sort state for view
    @current_filters = query.current_filters
    @current_sort = query.current_sort
    @current_view = query.current_view
    @has_active_filters = query.has_active_filters?
    
    @spotlight_stats = calculate_spotlight_stats
    
    # Create debug data if debug parameter is present
    if params[:debug] == 'true'
      debug_service = Debug::SeatsDebugService.new(
        pundit_user: pundit_user,
        organization: organization
      )
      @debug_data = debug_service.call
    end
    
    render layout: determine_layout
  end

  def show
    authorize @seat
    render layout: determine_layout
  end

  def new
    @seat = Seat.new
    authorize @seat
    render layout: determine_layout
  end

  def create
    @seat = Seat.new(seat_params)
    authorize @seat

    if @seat.save
      redirect_to organization_seat_path(organization, @seat), notice: 'Seat was successfully created.'
    else
      set_related_data
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @seat
    render layout: determine_layout
  end

  def update
    authorize @seat
    
    if @seat.update(seat_params)
      redirect_to organization_seat_path(organization, @seat), notice: 'Seat was successfully updated.'
    else
      set_related_data
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @seat
    @seat.destroy
    redirect_to organization_seats_path(organization), notice: 'Seat was successfully deleted.'
  end

  def reconcile
    authorize @seat
    @seat.reconcile_state!
    redirect_to organization_seat_path(@organization, @seat), notice: 'Seat state was successfully reconciled.'
  end

  def create_missing_employee_seats
    authorize Seat.new, :create?
    
    result = Seats::CreateMissingEmployeeSeatsService.new(organization).call
    
    if result[:success]
      redirect_to organization_seats_path(organization), notice: "Successfully created #{result[:created_count]} seat(s) for employees."
    else
      redirect_to organization_seats_path(organization), alert: "Failed to create seats: #{result[:errors].join(', ')}"
    end
  end

  def create_missing_position_type_seats
    authorize Seat.new, :create?
    
    result = Seats::CreateMissingPositionTypeSeatsService.new(organization).call
    
    if result[:success]
      redirect_to organization_seats_path(organization), notice: "Successfully created #{result[:created_count]} seat(s) for position types."
    else
      redirect_to organization_seats_path(organization), alert: "Failed to create seats: #{result[:errors].join(', ')}"
    end
  end

  def customize_view
    # Authorization: require ability to view seats
    authorize company, :view_seats?
    
    # Load current state from params or defaults
    query = SeatsQuery.new(organization, params)
    
    @current_filters = query.current_filters
    @current_sort = query.current_sort
    @current_view = query.current_view
    @has_active_filters = query.has_active_filters?
    
    # Preserve current params for return URL (excluding controller/action/page)
    return_params = params.except(:controller, :action, :page).permit!.to_h
    @return_url = organization_seats_path(organization, return_params)
    @return_text = "Back to Seats"
    
    render layout: 'overlay'
  end

  def update_view
    # Authorization: require ability to view seats
    authorize company, :view_seats?
    
    # Handle preset application if selected
    apply_preset_if_selected
    
    # Build redirect URL with view customization params
    if params[:preset].present?
      # When preset is selected, only include preset-defined params
      preset_params = preset_to_params(params[:preset])
      redirect_params = {}
      
      if preset_params
        # Use preset params directly - Rails path helpers handle arrays automatically
        redirect_params = preset_params.dup
      end
    else
      # When no preset, include all params except Rails internal ones
      redirect_params = params.except(:controller, :action, :authenticity_token, :_method, :commit).permit!.to_h.compact
    end
    
    redirect_to organization_seats_path(organization, redirect_params), notice: 'View updated successfully.'
  end

  private

  def set_seat
    @seat = Seat.includes(:position_type, :reports_to_seat, :reporting_seats, employment_tenures: { teammate: :person }).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    flash[:error] = "Seat not found"
    redirect_to organization_seats_path(organization)
  end

  def set_related_data
    @position_types = organization.position_types.ordered
    
    @departments = organization.descendants.select { |o| o.type == 'Department' }.sort_by(&:display_name)
    @teams = organization.descendants.select { |o| o.type == 'Team' }.sort_by(&:display_name)
    
    # Load seats with their active employment tenures and teammates
    all_seats = Seat.for_organization(organization)
                    .includes(:position_type, employment_tenures: { teammate: :person })
                    .order('position_types.external_title ASC, seats.seat_needed_by ASC')
    
    # Exclude current seat if editing (can't report to itself)
    current_seat_id = @seat&.id || params[:id]
    all_seats = all_seats.where.not(id: current_seat_id) if current_seat_id.present?
    
    # Separate into filled and unfilled
    @filled_seats = []
    @unfilled_seats = []
    
    all_seats.each do |seat|
      active_tenure = seat.employment_tenures.active.first
      if active_tenure && active_tenure.teammate
        @filled_seats << {
          seat: seat,
          tenure: active_tenure,
          teammate: active_tenure.teammate,
          person: active_tenure.teammate.person
        }
      else
        @unfilled_seats << seat
      end
    end
    
    # Sort filled seats by person's last_name, first_name
    @filled_seats.sort_by! { |item| [item[:person].last_name || '', item[:person].first_name || ''] }
  end

  def seat_params
    params.require(:seat).permit(
      :position_type_id,
      :seat_needed_by,
      :job_classification,
      :team,
      :department_id,
      :team_id,
      :reports_to_seat_id,
      :reports,
      :measurable_outcomes,
      :seat_disclaimer,
      :work_environment,
      :physical_requirements,
      :travel,
      :why_needed,
      :why_now,
      :costs_risks,
      :state
    )
  end

  def calculate_spotlight_stats
    # Calculate employee seat statistics
    active_teammates = Teammate.for_organization_hierarchy(organization)
                                .where.not(first_employed_at: nil)
                                .where(last_terminated_at: nil)
    
    active_employment_tenures = EmploymentTenure.active
                                                 .where(company: organization)
                                                 .includes(:seat, :position)
    
    employees_with_seats = active_employment_tenures.select { |et| et.seat.present? }.count
    employees_without_seats = active_employment_tenures.select { |et| et.seat.nil? }.count
    total_active_employees = active_employment_tenures.count
    
    # Calculate position type seat statistics
    position_types = organization.position_types.includes(:seats)
    position_types_with_seats = position_types.select { |pt| pt.seats.exists? }.count
    position_types_without_seats = position_types.select { |pt| !pt.seats.exists? }.count
    total_position_types = position_types.count
    
    {
      employees: {
        total: total_active_employees,
        with_seats: employees_with_seats,
        without_seats: employees_without_seats
      },
      position_types: {
        total: total_position_types,
        with_seats: position_types_with_seats,
        without_seats: position_types_without_seats
      }
    }
  end

  def apply_preset_if_selected
    return unless params[:preset].present?
    
    preset_params = preset_to_params(params[:preset])
    
    if preset_params
      preset_params.each do |key, value|
        params[key] = value
      end
    end
  end

  def preset_to_params(preset_name)
    case preset_name.to_s
    when 'seat_hierarchy'
      {
        view: 'seat_hierarchy'
      }
    else
      nil
    end
  end

  def filter_hierarchy_tree(hierarchy_tree, filtered_seat_ids)
    # Recursively filter the hierarchy tree to only include nodes matching filters
    hierarchy_tree.map do |node|
      seat_id = node[:seat]&.id
      next nil unless seat_id && filtered_seat_ids.include?(seat_id)
      
      # Recursively filter children
      filtered_children = filter_hierarchy_tree(node[:children] || [], filtered_seat_ids).compact
      
      # Recalculate counts based on filtered children
      direct_reports_count = filtered_children.length
      total_reports_count = direct_reports_count + filtered_children.sum { |child| child[:total_reports_count] || 0 }
      
      {
        seat: node[:seat],
        children: filtered_children,
        direct_reports_count: direct_reports_count,
        total_reports_count: total_reports_count
      }
    end.compact
  end
end
