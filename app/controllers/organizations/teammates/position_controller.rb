class Organizations::Teammates::PositionController < Organizations::OrganizationNamespaceBaseController
  before_action :authenticate_person!
  before_action :set_teammate
  after_action :verify_authorized

  def show
    authorize @teammate, :view_check_ins?, policy_class: CompanyTeammatePolicy
    
    # Set @person for view switcher
    @person = @teammate.person
    
    @check_ins = PositionCheckIn
      .where(teammate: @teammate)
      .includes(:finalized_by, :manager_completed_by, :employment_tenure)
      .order(check_in_started_on: :desc)
    
    @current_employment = @teammate.employment_tenures.active.first
    @employment_tenures = @teammate.employment_tenures
      .includes(:position, :manager, :seat)
      .order(started_at: :desc)
    @open_check_in = PositionCheckIn.where(teammate: @teammate).open.first
    
    # Create debug data if debug parameter is present
    if params[:debug] == 'true'
      debug_service = Debug::PositionDebugService.new(
        pundit_user: pundit_user,
        person: @teammate.person
      )
      @debug_data = debug_service.call
    end
    
    # Load form data
    load_form_data
  end

  def update
    authorize @teammate, :update?, policy_class: CompanyTeammatePolicy
    
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
    @employment_tenures = @teammate.employment_tenures
      .includes(:position, :manager, :seat)
      .order(started_at: :desc)
    @open_check_in = PositionCheckIn.where(teammate: @teammate).open.first
    
    # Load form data (this sets @managers, @all_employees, @positions, @seats)
    load_form_data
    
    # Create and validate the form
    @form = EmploymentTenureUpdateForm.new(@current_employment)
    @form.current_person = current_person
    @form.teammate = @teammate
    
    employment_params = params[:employment_tenure_update] || params[:employment_tenure] || {}
    
    if @form.validate(employment_params) && @form.save
      redirect_to organization_teammate_position_path(organization, @teammate),
                  notice: 'Position information was successfully updated.'
    else
      # Set @person for view switcher
      @person = @teammate.person
      render :show, status: :unprocessable_entity
    end
  end

  private

  def set_teammate
    @teammate = organization.teammates.find(params[:teammate_id])
  end

  def load_form_data
    company = organization.root_company || organization
    
    # Load distinct active managers (people who are managers in active employment tenures and are active company teammates)
    @managers = ActiveManagersQuery.new(company: company, require_active_teammate: true).call
    
    # Load all active employees (for manager selection)
    org_hierarchy = company.company? ? company.self_and_descendants : [company, company.parent].compact
    manager_ids = @managers.pluck(:id)
    
    # Get all active employees (people with active employment tenures in the organization hierarchy)
    all_active_employee_ids = EmploymentTenure.active
                                              .joins(:teammate)
                                              .where(company: org_hierarchy, teammates: { organization: org_hierarchy })
                                              .distinct
                                              .pluck('teammates.person_id')
    
    # Exclude managers and the current person being edited (to prevent self-management)
    person_ids_to_exclude = (manager_ids + [@teammate.person_id]).compact
    non_manager_employee_ids = all_active_employee_ids - person_ids_to_exclude
    
    # Get Person objects for non-manager employees, ordered by last_name, first_name
    @all_employees = Person.where(id: non_manager_employee_ids)
                           .order(:last_name, :first_name)
    
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
    
    # Initialize form for display (only if not already set in update action)
    unless @form
      @form = EmploymentTenureUpdateForm.new(@current_employment || EmploymentTenure.new)
      @form.current_person = current_person
      @form.teammate = @teammate
    end
  end

end

