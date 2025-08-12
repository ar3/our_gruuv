class EmploymentTenuresController < ApplicationController
  before_action :require_authentication
  before_action :set_person
  before_action :set_employment_tenure, only: [:show, :edit, :update, :destroy, :employment_summary]
  after_action :verify_authorized, except: :index
  after_action :verify_policy_scoped, only: :index

  def new
    # Just show company selection, will redirect to change
    authorize @person, policy_class: PersonPolicy
    @employment_tenure = EmploymentTenure.new
    @companies = Organization.companies.order(:name)
  end

  def change
    @company = Organization.find(params[:company_id]) if params[:company_id]
    @employment_tenure = EmploymentTenure.new
    
    if @company
      # Pre-populate from most recent employment at this company
      most_recent = EmploymentTenure.most_recent_for(@person, @company)
      if most_recent
        @employment_tenure.assign_attributes(
          company: @company,
          position: most_recent.position,
          manager: most_recent.manager,
          started_at: Date.current
        )
      else
        @employment_tenure.company = @company
        @employment_tenure.started_at = Date.current
      end
    end
    
    authorize @person, policy_class: PersonPolicy
    @managers = @company ? @company.employees : []
    @positions = @company ? @company.positions.includes(:position_type, :position_level) : []
  end

  def create
    @employment_tenure = @person.employment_tenures.build(employment_tenure_params)
    authorize @employment_tenure
    
    # Check if this is a job change (there's an active employment at the same company)
    active_tenure = @person.employment_tenures.for_company(@employment_tenure.company).active.first
    
    if active_tenure
      # This is a job change - check if anything actually changed
      if job_change_has_no_changes?(active_tenure, @employment_tenure)
        redirect_to person_path(@person), notice: 'No changes were made to your employment.'
        return
      end
      
      # Set the effective date for the transition
      effective_date = params[:effective_date] || @employment_tenure.started_at
      
      # Use a transaction to ensure data consistency
      ActiveRecord::Base.transaction do
        # End the current active tenure
        active_tenure.update!(ended_at: effective_date)
        
        # Set the new tenure start date to the effective date
        @employment_tenure.started_at = effective_date
        
        # Save the new tenure
        @employment_tenure.save!
        
        redirect_to person_path(@person), notice: 'Employment tenure was successfully created.'
      end
    else
      # Simple new employment creation
      if @employment_tenure.save
        redirect_to person_path(@person), notice: 'Employment tenure was successfully created.'
      else
        @company = @employment_tenure.company
        @managers = @company ? @company.employees : []
        @positions = @company ? @company.positions.includes(:position_type, :position_level) : []
        render :change, status: :unprocessable_entity
      end
    end
  rescue ActiveRecord::RecordInvalid
    # If save fails, we need to set up the form for re-rendering
    @company = @employment_tenure.company
    @managers = @company ? @company.employees : []
    @positions = @company ? @company.positions.includes(:position_type, :position_level) : []
    render :change, status: :unprocessable_entity
  end

  def show
    authorize @employment_tenure
    @employment_tenure = @employment_tenure.decorate
  end

  def edit
    authorize @employment_tenure
    # Don't allow changing company
    @company = @employment_tenure.company
    @managers = @company.employees
    @positions = @company.positions.includes(:position_type, :position_level)
  end

  def update
    authorize @employment_tenure
    if @employment_tenure.update(employment_tenure_params)
      redirect_to person_path(@person), notice: 'Employment tenure was successfully updated.'
    else
      @company = @employment_tenure.company
      @managers = @company.employees
      @positions = @company.positions.includes(:position_type, :position_level)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @employment_tenure
    @employment_tenure.destroy
    redirect_to person_path(@person), notice: 'Employment tenure was successfully deleted.'
  end

  def add_history
    # For adding historical employment records
    authorize @person, policy_class: PersonPolicy
    @employment_tenure = EmploymentTenure.new
    @companies = Organization.companies.order(:name)
  end

  def employment_summary
    authorize @person, policy_class: PersonPolicy
    @employment_tenures = @person.employment_tenures.includes(:company, :position, :manager)
                                 .order(started_at: :desc)
                                 .decorate
  end

  private

  def set_person
    @person = Person.find(params[:person_id])
  end

  def set_employment_tenure
    @employment_tenure = @person.employment_tenures.find(params[:id])
  end

  def employment_tenure_params
    params.require(:employment_tenure).permit(:company_id, :position_id, :manager_id, :started_at, :ended_at, :employment_change_notes)
  end

  def require_authentication
    unless current_person
      redirect_to root_path, alert: 'Please log in to access employment tenures.'
    end
  end


  
  def job_change_has_no_changes?(old_tenure, new_tenure)
    old_tenure.position_id == new_tenure.position_id &&
    old_tenure.manager_id == new_tenure.manager_id
  end
end
