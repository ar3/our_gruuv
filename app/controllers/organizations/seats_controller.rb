class Organizations::SeatsController < ApplicationController
  before_action :set_organization
  before_action :set_seat, only: [:show, :edit, :update, :destroy, :reconcile]
  before_action :set_related_data, only: [:new, :edit, :create, :update]

  def index
    @seats = policy_scope(Seat).includes(:position_type).ordered
  end

  def show
    authorize @seat
  end

  def new
    @seat = Seat.new
    authorize @seat
  end

  def create
    @seat = Seat.new(seat_params)
    authorize @seat

    if @seat.save
      redirect_to organization_seat_path(@organization, @seat), notice: 'Seat was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @seat
  end

  def update
    authorize @seat
    if @seat.update(seat_params)
      redirect_to organization_seat_path(@organization, @seat), notice: 'Seat was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @seat
    @seat.destroy
    redirect_to organization_seats_path(@organization), notice: 'Seat was successfully deleted.'
  end

  def reconcile
    authorize @seat
    @seat.reconcile_state!
    redirect_to organization_seat_path(@organization, @seat), notice: 'Seat state was successfully reconciled.'
  end

  private

  def set_organization
    @organization = Organization.find(params[:organization_id]) if params[:organization_id]
    @organization ||= current_organization
  end

  def set_seat
    @seat = Seat.includes(:position_type, :employment_tenures).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    flash[:error] = "Seat not found"
    redirect_to organization_seats_path(@organization)
  end

  def set_related_data
    @position_types = PositionType.for_company(@organization).ordered
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
