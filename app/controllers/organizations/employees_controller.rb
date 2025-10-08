class Organizations::EmployeesController < Organizations::OrganizationNamespaceBaseController
  before_action :require_authentication
  after_action :verify_authorized
  
  def index
    # Basic authorization - user should be able to view the organization
    authorize @organization, :show?
    
    # Get all teammates from this organization and its descendants
    @teammates = Teammate.for_organization_hierarchy(@organization)
                        .includes(:person, :employment_tenures, :organization)
                        .order('people.last_name, people.first_name')
    
    # Calculate spotlight statistics
    @spotlight_stats = {
      total_teammates: @teammates.count,
      followers: @teammates.select { |t| TeammateStatus.new(t).status == :follower }.count,
      huddlers: @teammates.select { |t| TeammateStatus.new(t).status == :huddler }.count,
      unassigned_employees: @teammates.select { |t| TeammateStatus.new(t).status == :unassigned_employee }.count,
      assigned_employees: @teammates.select { |t| TeammateStatus.new(t).status == :assigned_employee }.count,
      terminated: @teammates.select { |t| TeammateStatus.new(t).status == :terminated }.count,
      unknown: @teammates.select { |t| TeammateStatus.new(t).status == :unknown }.count,
      huddle_participants: @organization.huddle_participants.count,
      non_employee_participants: @organization.just_huddle_participants.count
    }
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
  
  def require_authentication
    unless current_person
      redirect_to root_path, alert: 'Please log in to access organizations.'
    end
  end

  private

  def person_params
    params.require(:person).permit(:first_name, :last_name, :email, :phone_number, :timezone)
  end

  def employment_tenure_params
    params.require(:employment_tenure).permit(:position_id, :manager_id, :started_at, :employment_change_notes)
  end
end
