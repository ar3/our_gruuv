class Organizations::EmployeesController < ApplicationController
  before_action :require_authentication
  before_action :set_organization
  after_action :verify_authorized
  
  def index
    # Basic authorization - user should be able to view the organization
    authorize @organization, :show?
    
    # Get active employees (people with active employment tenures)
    @active_employees = @organization.employees.includes(:employment_tenures)
    
    # Get huddle participants from this organization and all child organizations
    @huddle_participants = @organization.huddle_participants.includes(:employment_tenures)
    
    # Get just huddle participants (non-employees)
    @just_huddle_participants = @organization.just_huddle_participants.includes(:employment_tenures)
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
      
      @employment_tenure = @person.employment_tenures.build(employment_tenure_params)
      @employment_tenure.company = @organization
      @employment_tenure.save!
      
      redirect_to person_path(@person), notice: 'Employee was successfully created.'
    end
  rescue ActiveRecord::RecordInvalid
    @positions = @organization.positions.includes(:position_type, :position_level)
    @managers = @organization.employees
    render :new_employee, status: :unprocessable_entity
  end
  
  private
  
  def set_organization
    @organization = Organization.find(params[:organization_id])
  end
  
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
