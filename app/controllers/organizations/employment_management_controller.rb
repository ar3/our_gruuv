class Organizations::EmploymentManagementController < Organizations::OrganizationNamespaceBaseController
  before_action :require_authentication
  before_action :set_wizard_data, only: [:new, :create]
  after_action :verify_authorized, except: [:potential_employees]
  
  def index
    # Show potential employees and option to create new - but handle permissions in view
    authorize @organization, :show?  # Allow viewing, but creation permissions handled in view
    @potential_employees = load_potential_employees
  end
  
  def new
    # Step 1: Show potential employees + new person option
    authorize @organization, :create_employment?
    @potential_employees = load_potential_employees
  end
  
  def create
    # Step 2: Create person and employment
    authorize @organization, :create_employment?
    
    if params[:person_id].present?
      # Using existing person
      @person = Person.find(params[:person_id])
      create_employment_for_existing_person
    else
      # Creating new person
      create_new_person_and_employment
    end
  end
  
  def potential_employees
    # AJAX endpoint for potential employee search
    authorize @organization, :create_employment?
    @potential_employees = load_potential_employees
    render json: @potential_employees.map { |person| 
      { 
        id: person.id, 
        name: person.display_name, 
        email: person.email,
        reason: potential_employee_reason(person)
      } 
    }
  end
  
  private
  
  def set_wizard_data
    @positions = @organization.positions.includes(:position_type, :position_level)
    @managers = @organization.employees
    @employment_tenure = EmploymentTenure.new
  end
  
  def load_potential_employees
    # People who have access or huddle participation but no employment
    potential_people = []
    
    # People with access permissions but no employment
    access_people = @organization.teammates.includes(:person)
      .where.not(person: @organization.employees)
      .map(&:person)
    
    # People who participated in huddles but no employment
    huddle_people = @organization.huddle_participants
      .where.not(id: @organization.employees.select(:id))
    
    # Combine and deduplicate
    (access_people + huddle_people).uniq
  end
  
  def potential_employee_reason(person)
    reasons = []
    reasons << "Has access permissions" if @organization.teammates.exists?(person: person)
    reasons << "Participated in huddles" if @organization.huddle_participants.where(id: person.id).exists?
    reasons.join(", ")
  end
  
  def create_employment_for_existing_person
    # Find or create teammate for this person and organization
    teammate = @person.teammates.find_or_create_by(organization: @organization) do |t|
      t.type = 'CompanyTeammate'
    end
    
    @employment_tenure = @person.employment_tenures.build(employment_tenure_params)
    @employment_tenure.company = @organization
    @employment_tenure.teammate = teammate
    
    if @employment_tenure.save
      redirect_to person_path(@person), notice: 'Employment was successfully created.'
    else
      @potential_employees = load_potential_employees
      render :new, status: :unprocessable_entity
    end
  end
  
  def create_new_person_and_employment
    ActiveRecord::Base.transaction do
      @person = Person.new(person_params)
      @person.save!
      
      # Create teammate for this person and organization
      teammate = @person.teammates.create!(
        organization: @organization,
        type: 'CompanyTeammate'
      )
      
      @employment_tenure = @person.employment_tenures.build(employment_tenure_params)
      @employment_tenure.company = @organization
      @employment_tenure.teammate = teammate
      @employment_tenure.save!
      
      if params[:save_and_continue] == 'true'
        redirect_to person_path(@person), notice: 'Employee was successfully created.'
      else
        redirect_to new_organization_employment_management_path(@organization), notice: 'Employee was successfully created. Creating another...'
      end
    end
  rescue ActiveRecord::RecordInvalid
    @potential_employees = load_potential_employees
    render :new, status: :unprocessable_entity
  end
  
  def person_params
    params.require(:person).permit(:first_name, :last_name, :email, :phone_number, :timezone)
  end
  
  def employment_tenure_params
    params.require(:employment_tenure).permit(:position_id, :manager_id, :started_at, :employment_change_notes)
  end
  
  def require_authentication
    unless current_person
      redirect_to root_path, alert: 'Please log in to access organizations.'
    end
  end
end
