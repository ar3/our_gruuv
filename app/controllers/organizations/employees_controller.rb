class Organizations::EmployeesController < Organizations::OrganizationNamespaceBaseController
  before_action :require_authentication
  after_action :verify_authorized
  
  def index
    # Basic authorization - user should be able to view the organization
    authorize @organization, :show?
    
    # Use TeammatesQuery for filtering and sorting
    query = TeammatesQuery.new(@organization, params)
    
    # Get paginated teammates
    @pagy, @teammates = pagy(query.call, items: 25)
    
    # Calculate spotlight statistics from filtered teammates (not paginated)
    filtered_teammates = query.call
    @spotlight_stats = calculate_spotlight_stats(filtered_teammates)
    
    # Store current filter/sort state for view
    @current_filters = query.current_filters
    @current_sort = query.current_sort
    @current_view = query.current_view
    @has_active_filters = query.has_active_filters?
  end

  def new_employee
    # For creating a new person and employment simultaneously
    authorize @organization, :manage_employment?
    @person = Person.new
    @employment_tenure = EmploymentTenure.new
    @positions = @organization.positions.includes(:position_type, :position_level)
    @managers = @organization.employees
  end

  def create_employee
    # For creating a new person and employment simultaneously
    authorize @organization, :manage_employment?
    
    # Create person and employment in a transaction
    ActiveRecord::Base.transaction do
      @person = Person.new(person_params)
      @person.save!
      
      # Create teammate for this person and organization
      teammate = @person.teammates.create!(
        organization: @organization,
        type: 'CompanyTeammate'
      )
      
      @employment_tenure = teammate.employment_tenures.build(employment_tenure_params)
      @employment_tenure.company = @organization
      @employment_tenure.teammate = teammate
      @employment_tenure.save!
      
      redirect_to person_path(@person), notice: 'Employee was successfully created.'
    end
  rescue ActiveRecord::RecordInvalid
    @positions = @organization.positions.includes(:position_type, :position_level)
    @managers = @organization.employees
    render :new_employee, status: :unprocessable_entity
  end

  def audit
    # Find the person/employee
    @person = @organization.employees.find(params[:id])
    
    # Authorize access to audit view (organization context passed via pundit_user)
    authorize @person, :audit?
    
    # Get MAAP snapshots for this person within this organization
    @maap_snapshots = MaapSnapshot.for_employee(@person)
                                  .for_company(@organization)
                                  .recent
                                  .includes(:created_by)
  end
  
  private

  def calculate_spotlight_stats(teammates)
    {
      total_teammates: teammates.count,
      followers: teammates.select { |t| TeammateStatus.new(t).status == :follower }.count,
      huddlers: teammates.select { |t| TeammateStatus.new(t).status == :huddler }.count,
      unassigned_employees: teammates.select { |t| TeammateStatus.new(t).status == :unassigned_employee }.count,
      assigned_employees: teammates.select { |t| TeammateStatus.new(t).status == :assigned_employee }.count,
      terminated: teammates.select { |t| TeammateStatus.new(t).status == :terminated }.count,
      unknown: teammates.select { |t| TeammateStatus.new(t).status == :unknown }.count,
      huddle_participants: teammates.joins(:huddle_participants).distinct.count,
      non_employee_participants: teammates.joins(:huddle_participants).where(first_employed_at: nil).distinct.count
    }
  end

  def require_authentication
    unless current_person
      redirect_to root_path, alert: 'Please log in to access organizations.'
    end
  end

  def person_params
    params.require(:person).permit(:first_name, :last_name, :email, :phone_number, :timezone)
  end

  def employment_tenure_params
    params.require(:employment_tenure).permit(:position_id, :manager_id, :started_at, :employment_change_notes)
  end
end
