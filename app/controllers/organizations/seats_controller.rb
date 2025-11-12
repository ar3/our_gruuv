class Organizations::SeatsController < Organizations::OrganizationNamespaceBaseController
  before_action :set_seat, only: [:show, :edit, :update, :destroy, :reconcile]
  before_action :set_related_data, only: [:new, :edit, :create, :update]

  def index
    @seats = policy_scope(Seat.for_organization(organization))
              .includes(:position_type, employment_tenures: { teammate: :person })
              .ordered
    @spotlight_stats = calculate_spotlight_stats
    render layout: 'authenticated-v2-0'
  end

  def show
    authorize @seat
    render layout: 'authenticated-v2-0'
  end

  def new
    @seat = Seat.new
    authorize @seat
    render layout: 'authenticated-v2-0'
  end

  def create
    @seat = Seat.new(seat_params)
    authorize @seat

    if @seat.save
      redirect_to organization_seat_path(organization, @seat), notice: 'Seat was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @seat
    render layout: 'authenticated-v2-0'
  end

  def update
    authorize @seat
    if @seat.update(seat_params)
      redirect_to organization_seat_path(organization, @seat), notice: 'Seat was successfully updated.'
    else
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

  private

  def set_seat
    @seat = Seat.includes(:position_type, :employment_tenures).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    flash[:error] = "Seat not found"
    redirect_to organization_seats_path(organization)
  end

  def set_related_data
    @position_types = organization.position_types.ordered
  end

  def seat_params
    params.require(:seat).permit(
      :position_type_id,
      :seat_needed_by,
      :job_classification,
      :reports_to,
      :team,
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
end
