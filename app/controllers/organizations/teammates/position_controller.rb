class Organizations::Teammates::PositionController < Organizations::OrganizationNamespaceBaseController
  before_action :authenticate_person!
  before_action :set_teammate
  after_action :verify_authorized

  def show
    authorize @teammate, :view_check_ins?, policy_class: CompanyTeammatePolicy
    
    # Set @person for view switcher
    @person = @teammate.person
    
    # Set return URL and text from parameters
    @return_url = params[:return_url] || organization_company_teammate_check_ins_path(organization, @teammate)
    @return_text = params[:return_text] || "Back to Check-ins"
    
    @check_ins = PositionCheckIn
      .where(company_teammate: @teammate)
      .includes(:finalized_by_teammate, :manager_completed_by_teammate, :employment_tenure)
      .order(check_in_started_on: :desc)
    
    @current_employment = @teammate.employment_tenures.active.first
    @employment_tenures = @teammate.employment_tenures
      .includes(:position, :manager_teammate, :seat)
      .order(started_at: :desc)
    @open_check_in = PositionCheckIn.where(company_teammate: @teammate).open.first
    
    # Load inactive tenures to determine Start vs Restart
    @inactive_tenures = @teammate.employment_tenures.inactive.order(ended_at: :desc)
    @has_inactive_tenures = @inactive_tenures.any?
    @latest_inactive_end_date = @inactive_tenures.first&.ended_at
    
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
    
    employment_params = params[:employment_tenure_update] || params[:employment_tenure] || {}
    
    # Load check-ins for the view (in case validation fails and we render :show)
    @check_ins = PositionCheckIn
                   .where(company_teammate: @teammate)
                   .includes(:finalized_by_teammate, :manager_completed_by_teammate, :employment_tenure)
                   .order(check_in_started_on: :desc)
    @employment_tenures = @teammate.employment_tenures
      .includes(:position, :manager_teammate, :seat)
      .order(started_at: :desc)
    @open_check_in = PositionCheckIn.where(company_teammate: @teammate).open.first
    
    # Load inactive tenures for view consistency
    @inactive_tenures = @teammate.employment_tenures.inactive.order(ended_at: :desc)
    @has_inactive_tenures = @inactive_tenures.any?
    @latest_inactive_end_date = @inactive_tenures.first&.ended_at
    
    # Load form data (this sets @managers, @all_employees, @positions, @seats)
    load_form_data
    
    # Create and validate the form
    @form = EmploymentTenureUpdateForm.new(@current_employment)
    @form.current_company_teammate = current_company_teammate
    @form.teammate = @teammate
    
    if @form.validate(employment_params) && @form.save
      redirect_to organization_teammate_position_path(organization, @teammate),
                  notice: 'Position information was successfully updated.'
    else
      # Set @person for view switcher
      @person = @teammate.person
      render :show, status: :unprocessable_entity
    end
  end

  def confirm_termination
    authorize @teammate, :update?, policy_class: CompanyTeammatePolicy
    
    @current_employment = @teammate.employment_tenures.active.first
    
    unless @current_employment
      redirect_to organization_teammate_position_path(organization, @teammate), 
                  alert: 'No active employment tenure found.'
      return
    end
    
    @person = @teammate.person
    
    # Optional: if termination_date in params (e.g. old bookmark), validate and pre-fill form
    if params[:termination_date].present?
      begin
        @parsed_termination_date = if params[:termination_date].is_a?(String)
          if params[:termination_date].match?(/\A\d{4}-\d{2}-\d{2}\z/)
            Date.strptime(params[:termination_date], '%Y-%m-%d')
          else
            Date.parse(params[:termination_date])
          end
        elsif params[:termination_date].is_a?(Date)
          params[:termination_date]
        else
          Date.parse(params[:termination_date].to_s)
        end
        @termination_date_for_form = @parsed_termination_date.strftime('%Y-%m-%d')
      rescue ArgumentError
        redirect_to organization_teammate_position_path(organization, @teammate),
                    alert: 'Invalid termination date.'
        return
      end
    else
      @termination_date_for_form = Date.current.strftime('%Y-%m-%d')
    end
    @reason_for_form = nil
  end

  def process_termination
    authorize @teammate, :update?, policy_class: CompanyTeammatePolicy
    
    @current_employment = @teammate.employment_tenures.active.first
    
    unless @current_employment
      redirect_to organization_teammate_position_path(organization, @teammate), 
                  alert: 'No active employment tenure found.'
      return
    end
    
    termination_date = params[:termination_date]
    reason = params[:reason].to_s.strip.presence

    if termination_date.blank?
      render_confirm_termination_with_error('Employment ended on date is required.', termination_date, reason)
      return
    end

    begin
      Date.parse(termination_date.to_s)
    rescue ArgumentError
      render_confirm_termination_with_error('Employment ended on date must be a valid date.', termination_date, reason)
      return
    end

    if reason.blank?
      render_confirm_termination_with_error('Reason is required.', termination_date, reason)
      return
    end
    
    result = TerminateEmploymentService.call(
      teammate: @teammate,
      current_tenure: @current_employment,
      termination_date: termination_date,
      created_by: current_company_teammate,
      reason: reason
    )
    
    if result.ok?
      redirect_to organization_teammate_position_path(organization, @teammate),
                  notice: 'Employment was successfully terminated.'
    else
      redirect_to organization_teammate_position_path(organization, @teammate),
                  alert: "Failed to terminate employment: #{result.error}"
    end
  end

  def create_employment
    authorize @teammate, :update?, policy_class: CompanyTeammatePolicy
    
    company = organization.root_company || organization
    
    # Load inactive tenures for validation
    inactive_tenures = @teammate.employment_tenures.inactive.order(ended_at: :desc)
    latest_inactive_end_date = inactive_tenures.first&.ended_at
    
    # Get form parameters
    position_id = params[:employment_tenure][:position_id]
    manager_teammate_id = params[:employment_tenure][:manager_teammate_id].presence
    started_at = params[:employment_tenure][:started_at]
    
    # Validate required fields
    unless position_id.present? && started_at.present?
      @current_employment = @teammate.employment_tenures.active.first
      @employment_tenures = @teammate.employment_tenures.includes(:position, :manager_teammate, :seat).order(started_at: :desc)
      @inactive_tenures = inactive_tenures
      @has_inactive_tenures = inactive_tenures.any?
      @latest_inactive_end_date = latest_inactive_end_date
      @person = @teammate.person
      @check_ins = PositionCheckIn.where(company_teammate: @teammate).includes(:finalized_by_teammate, :manager_completed_by_teammate, :employment_tenure).order(check_in_started_on: :desc)
      @open_check_in = PositionCheckIn.where(company_teammate: @teammate).open.first
      load_form_data
      @employment_tenure = EmploymentTenure.new
      @employment_tenure.errors.add(:position_id, "can't be blank") unless position_id.present?
      @employment_tenure.errors.add(:started_at, "can't be blank") unless started_at.present?
      render :show, status: :unprocessable_entity
      return
    end
    
    # Find position
    position = Position.find_by(id: position_id)
    unless position
      @current_employment = @teammate.employment_tenures.active.first
      @employment_tenures = @teammate.employment_tenures.includes(:position, :manager_teammate, :seat).order(started_at: :desc)
      @inactive_tenures = inactive_tenures
      @has_inactive_tenures = inactive_tenures.any?
      @latest_inactive_end_date = latest_inactive_end_date
      @person = @teammate.person
      @check_ins = PositionCheckIn.where(company_teammate: @teammate).includes(:finalized_by_teammate, :manager_completed_by_teammate, :employment_tenure).order(check_in_started_on: :desc)
      @open_check_in = PositionCheckIn.where(company_teammate: @teammate).open.first
      load_form_data
      @employment_tenure = EmploymentTenure.new
      @employment_tenure.errors.add(:position_id, "does not exist")
      render :show, status: :unprocessable_entity
      return
    end
    
    # Parse start date
    start_datetime = Time.zone.parse(started_at)
    
    # If restarting and start date is before or equal to latest inactive end date, adjust it
    if latest_inactive_end_date && start_datetime <= latest_inactive_end_date
      start_datetime = latest_inactive_end_date + 1.minute
    end
    
    # Find or create manager teammate if provided
    manager_teammate = nil
    if manager_teammate_id.present?
      manager_teammate = CompanyTeammate.find_by(id: manager_teammate_id, organization: company)
    end
    
    # Create employment tenure
    @employment_tenure = @teammate.employment_tenures.build(
      company: company,
      position: position,
      manager_teammate: manager_teammate,
      started_at: start_datetime,
      employment_type: 'full_time',
      seat_id: nil
    )
    
    if @employment_tenure.save
      redirect_to organization_teammate_position_path(organization, @teammate),
                  notice: 'Employment was successfully started.'
    else
      @current_employment = @teammate.employment_tenures.active.first
      @employment_tenures = @teammate.employment_tenures.includes(:position, :manager_teammate, :seat).order(started_at: :desc)
      @inactive_tenures = inactive_tenures
      @has_inactive_tenures = inactive_tenures.any?
      @latest_inactive_end_date = latest_inactive_end_date
      @person = @teammate.person
      @check_ins = PositionCheckIn.where(company_teammate: @teammate).includes(:finalized_by_teammate, :manager_completed_by_teammate, :employment_tenure).order(check_in_started_on: :desc)
      @open_check_in = PositionCheckIn.where(company_teammate: @teammate).open.first
      load_form_data
      render :show, status: :unprocessable_entity
    end
  end

  private

  def render_confirm_termination_with_error(alert_message, termination_date, reason)
    @person = @teammate.person
    @termination_date_for_form = termination_date.presence || Date.current.strftime('%Y-%m-%d')
    @reason_for_form = reason
    flash.now[:alert] = alert_message
    render :confirm_termination, status: :unprocessable_entity
  end

  def set_teammate
    @teammate = organization.teammates.find(params[:teammate_id])
  end

  def load_form_data
    company = organization.root_company || organization
    
    # Load distinct active managers (CompanyTeammates who are managers in active employment tenures)
    # Note: ActiveManagersQuery will need to be updated to return CompanyTeammate objects
    active_manager_teammates = ActiveManagersQuery.new(company: company, require_active_teammate: true).call
    @managers = active_manager_teammates
    
    # Load all active employees (for manager selection)
    # Organizations no longer have parent hierarchy - use the company directly
    org_hierarchy = [company]
    manager_teammate_ids = @managers.map { |m| m.is_a?(CompanyTeammate) ? m.id : CompanyTeammate.find_by(organization: company, person: m)&.id }.compact
    
    # Get all active employees (CompanyTeammates with active employment tenures in the organization hierarchy)
    all_active_teammate_ids = EmploymentTenure.active
                                              .joins(:company_teammate)
                                              .where(company: org_hierarchy, teammates: { organization: org_hierarchy })
                                              .distinct
                                              .pluck('teammates.id')
    
    # Exclude managers and the current teammate being edited (to prevent self-management)
    manager_teammate_ids = @managers.map { |m| m.is_a?(CompanyTeammate) ? m.id : CompanyTeammate.find_by(organization: company, person: m)&.id }.compact
    teammate_ids_to_exclude = (manager_teammate_ids + [@teammate.id]).compact
    non_manager_teammate_ids = all_active_teammate_ids - teammate_ids_to_exclude
    
    # Get CompanyTeammate objects for non-manager employees, ordered by person's last_name, first_name
    @all_employees = CompanyTeammate.where(id: non_manager_teammate_ids)
                                    .joins(:person)
                                    .order('people.last_name, people.first_name')
    
    # Load positions - all positions for company (titles under this org or its departments)
    positions = Position.joins(title: :company)
                        .where(titles: { company_id: company.id })
                        .includes(:title, :position_level)
                        .ordered
    
    # Group positions by department (nil = company-level; Department = that department)
    @positions_by_department = positions.group_by { |pos| pos.title.department || company }
    
    # Keep flat array for backward compatibility
    @positions = positions
    
    # Load seats: only seats NOT associated with active employment tenures, but include current tenure's seat
    active_seat_ids = EmploymentTenure.active
                                      .where(company: company)
                                      .where.not(seat_id: nil)
                                      .pluck(:seat_id)
    
    available_seats = company.seats
                             .includes(:title)
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
      @form.current_company_teammate = current_company_teammate
      @form.teammate = @teammate
    end
  end

end

