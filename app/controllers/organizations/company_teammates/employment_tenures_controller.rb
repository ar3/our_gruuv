class Organizations::CompanyTeammates::EmploymentTenuresController < Organizations::OrganizationNamespaceBaseController
  before_action :require_authentication
  before_action :set_teammate
  before_action :set_employment_tenure, only: [:show, :edit, :update, :destroy, :employment_summary]
  after_action :verify_authorized

  def new
    # Just show company selection, will redirect to change
    authorize @teammate, :update?, policy_class: CompanyTeammatePolicy
    @person = @teammate.person
    @employment_tenure = EmploymentTenure.new
    @companies = Organization.companies.order(:name)
  end

  def change
    @company = Organization.find(params[:company_id]) if params[:company_id]
    @employment_tenure = EmploymentTenure.new
    
    if @company
      # Pre-populate from most recent employment at this company
      teammate = @teammate.person.teammates.find_by(organization: @company)
      most_recent = teammate ? EmploymentTenure.most_recent_for(teammate, @company) : nil
      if most_recent
        @employment_tenure.assign_attributes(
          company: @company,
          position: most_recent.position,
          manager_teammate: most_recent.manager_teammate,
          started_at: Date.current
        )
      else
        @employment_tenure.company = @company
        @employment_tenure.started_at = Date.current
      end
    end
    
    authorize @teammate, :update?, policy_class: CompanyTeammatePolicy
    @managers = @company ? @company.teammates.where(type: 'CompanyTeammate').includes(:person).order('people.last_name, people.first_name') : []
    @positions = @company ? @company.positions.includes(:title, :position_level) : []
    @seats = @company ? @company.seats.includes(:title).where(state: [:open, :filled]) : []
  end

  def create
    # Use the teammate from set_teammate (already in the organization context)
    company = Organization.find(employment_tenure_params[:company_id])
    
    # Find or create teammate for this person and company
    target_teammate = @teammate.person.teammates.find_or_create_by(organization: company) do |t|
      t.type = 'CompanyTeammate'
    end
    
    @employment_tenure = target_teammate.employment_tenures.build(employment_tenure_params)
    @employment_tenure.teammate = target_teammate
    authorize @employment_tenure
    
    # Check if this is a job change (there's an active employment at the same company)
    active_tenure = target_teammate.employment_tenures.for_company(@employment_tenure.company).active.first
    
    if active_tenure
      # This is a job change - check if anything actually changed
      if job_change_has_no_changes?(active_tenure, @employment_tenure)
        redirect_to organization_company_teammate_path(@employment_tenure.company, target_teammate), notice: 'No changes were made to your employment.'
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
        
        # Create observable moment for seat change
        ObservableMoments::CreateSeatChangeMomentService.call(
          new_employment_tenure: @employment_tenure,
          old_employment_tenure: active_tenure,
          created_by: current_person
        )
        
        redirect_to organization_company_teammate_path(@employment_tenure.company, target_teammate), notice: 'Employment tenure was successfully created.'
      end
    else
      # Simple new employment creation
      if @employment_tenure.save
        # Create observable moment for new hire
        ObservableMoments::CreateNewHireMomentService.call(
          employment_tenure: @employment_tenure,
          created_by: current_person
        )
        
        redirect_to organization_company_teammate_path(@employment_tenure.company, target_teammate), notice: 'Employment tenure was successfully created.'
      else
        @company = @employment_tenure.company
        @managers = @company ? @company.teammates.where(type: 'CompanyTeammate').includes(:person).order('people.last_name, people.first_name') : []
        @positions = @company ? @company.positions.includes(:title, :position_level) : []
        @seats = @company ? @company.seats.includes(:title).where(state: [:open, :filled]) : []
        render :change, status: :unprocessable_entity
      end
    end
  rescue ActiveRecord::RecordInvalid
    # If save fails, we need to set up the form for re-rendering
    @company = @employment_tenure.company
    @managers = @company ? @company.teammates.where(type: 'CompanyTeammate').includes(:person).order('people.last_name, people.first_name') : []
    @positions = @company ? @company.positions.includes(:title, :position_level) : []
    @seats = @company ? @company.seats.includes(:title).where(state: [:open, :filled]) : []
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
    @managers = @company.teammates.where(type: 'CompanyTeammate').includes(:person).order('people.last_name, people.first_name')
    @positions = @company.positions.includes(:title, :position_level)
    @seats = @company.seats.includes(:title).where(state: [:open, :filled])
  end

  def update
    authorize @employment_tenure
    if @employment_tenure.update(employment_tenure_params)
      redirect_to organization_company_teammate_path(@employment_tenure.company, @employment_tenure.teammate), notice: 'Employment tenure was successfully updated.'
    else
      @company = @employment_tenure.company
      @managers = @company.teammates.where(type: 'CompanyTeammate').includes(:person).order('people.last_name, people.first_name')
      @positions = @company.positions.includes(:title, :position_level)
      @seats = @company.seats.includes(:title).where(state: [:open, :filled])
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @employment_tenure
    company = @employment_tenure.company
    teammate = @employment_tenure.teammate
    @employment_tenure.destroy
    redirect_to organization_company_teammate_path(company, teammate), notice: 'Employment tenure was successfully deleted.'
  end

  def add_history
    # For adding historical employment records
    authorize @teammate, :update?, policy_class: CompanyTeammatePolicy
    @employment_tenure = EmploymentTenure.new
    @companies = Organization.companies.order(:name)
  end

  def employment_summary
    authorize @teammate, :show?, policy_class: CompanyTeammatePolicy
    @person = @teammate.person
    @employment_tenures = EmploymentTenure.joins(:teammate)
                                          .where(teammates: { person: @teammate.person })
                                          .includes(:company, :position, :manager_teammate)
                                          .order(started_at: :desc)
                                          .decorate
  end

  private

  def set_teammate
    @teammate = organization.teammates.find(params[:company_teammate_id])
  end

  def set_employment_tenure
    @employment_tenure = EmploymentTenure.joins(:teammate)
                                        .where(teammates: { person: @teammate.person })
                                        .find(params[:id])
  end

  def employment_tenure_params
    params.require(:employment_tenure).permit(:company_id, :position_id, :manager_teammate_id, :seat_id, :started_at, :ended_at, :employment_change_notes)
  end

  def require_authentication
    unless current_person
      redirect_to root_path, alert: 'Please log in to access employment tenures.'
    end
  end

  def job_change_has_no_changes?(old_tenure, new_tenure)
    old_tenure.position_id == new_tenure.position_id &&
    old_tenure.manager_teammate_id == new_tenure.manager_teammate_id
  end
end



