class Organizations::Teammates::PositionController < Organizations::OrganizationNamespaceBaseController
  layout 'authenticated-v2-0'
  before_action :authenticate_person!
  before_action :set_teammate
  after_action :verify_authorized

  def show
    authorize @teammate.person, :view_check_ins?, policy_class: PersonPolicy
    
    @check_ins = PositionCheckIn
      .where(teammate: @teammate)
      .includes(:finalized_by, :manager_completed_by, :employment_tenure)
      .order(check_in_started_on: :desc)
    
    @current_employment = @teammate.employment_tenures.active.first
    @open_check_in = PositionCheckIn.where(teammate: @teammate).open.first
    
    # Load form data
    load_form_data
  end

  def update
    authorize @teammate.person, :change_employment?, policy_class: PersonPolicy
    
    @current_employment = @teammate.employment_tenures.active.first
    
    unless @current_employment
      redirect_to organization_teammate_position_path(organization, @teammate), 
                  alert: 'No active employment tenure found.'
      return
    end
    
    # Load check-ins for the view (in case validation fails and we render :show)
    @check_ins = PositionCheckIn
                   .where(teammate: @teammate)
                   .includes(:position_check_in_ratings)
                   .order(created_at: :desc)
    @open_check_in = PositionCheckIn.where(teammate: @teammate).open.first
    
    # Load form data first (this sets @managers, @positions, @seats)
    company = organization.root_company || organization
    
    # Load managers (employees)
    @managers = company.employees.order(:last_name, :first_name)
    
    # Load positions
    @positions = company.positions.includes(:position_type, :position_level).ordered
    
    # Load seats: only seats NOT associated with active employment tenures, but include current tenure's seat
    active_seat_ids = EmploymentTenure.active
                                      .where(company: company)
                                      .where.not(seat_id: nil)
                                      .pluck(:seat_id)
    
    available_seats = company.seats
                             .includes(:position_type)
                             .where.not(id: active_seat_ids)
                             .where(state: [:open, :filled])
    
    # Always include current tenure's seat if it exists
    if @current_employment&.seat
      @seats = (available_seats + [@current_employment.seat]).uniq
    else
      @seats = available_seats
    end
    
    # Now create and validate the form
    @form = EmploymentTenureUpdateForm.new(@current_employment)
    @form.current_person = current_person
    @form.teammate = @teammate
    
    employment_params = params[:employment_tenure_update] || params[:employment_tenure] || {}
    
    if @form.validate(employment_params) && @form.save
      redirect_to organization_teammate_position_path(organization, @teammate),
                  notice: 'Position information was successfully updated.'
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def set_teammate
    @teammate = organization.teammates.find(params[:teammate_id])
  end

  def load_form_data
    company = organization.root_company || organization
    
    # Load managers (employees)
    @managers = company.employees.order(:last_name, :first_name)
    
    # Load positions
    @positions = company.positions.includes(:position_type, :position_level).ordered
    
    # Load seats: only seats NOT associated with active employment tenures, but include current tenure's seat
    active_seat_ids = EmploymentTenure.active
                                      .where(company: company)
                                      .where.not(seat_id: nil)
                                      .pluck(:seat_id)
    
    available_seats = company.seats
                             .includes(:position_type)
                             .where.not(id: active_seat_ids)
                             .where(state: [:open, :filled])
    
    # Always include current tenure's seat if it exists
    if @current_employment&.seat
      @seats = (available_seats + [@current_employment.seat]).uniq
    else
      @seats = available_seats
    end
    
    # Initialize form for display
    @form = EmploymentTenureUpdateForm.new(@current_employment || EmploymentTenure.new)
    @form.current_person = current_person
    @form.teammate = @teammate
  end

end

