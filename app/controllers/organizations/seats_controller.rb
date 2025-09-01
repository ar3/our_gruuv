class Organizations::SeatsController < Organizations::OrganizationNamespaceBaseController
  before_action :set_seat, only: [:show, :edit, :update, :destroy, :reconcile]
  before_action :set_related_data, only: [:new, :edit, :create, :update]

  def index
    @seats = policy_scope(Seat.for_organization(organization)).includes(:position_type).ordered
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
end
