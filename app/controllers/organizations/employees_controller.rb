class Organizations::EmployeesController < Organizations::OrganizationNamespaceBaseController
  include TeammateHelper
  
  before_action :require_authentication
  after_action :verify_authorized
  
  def index
    # Basic authorization - user should be able to view the organization
    authorize @organization, :show?
    
    # Additional authorization for manager filter
    if params[:manager_filter] == 'direct_reports' && (!current_person || !current_person.has_direct_reports?(@organization))
      redirect_to organization_employees_path(@organization), 
                  alert: 'You do not have any direct reports in this organization.'
      return
    end
    
    # Use TeammatesQuery for filtering and sorting
    query = TeammatesQuery.new(@organization, params, current_person: current_person)
    
    # Get teammates with all filters except status (to keep ActiveRecord relation)
    filtered_teammates = query.call
    
    # Apply status filter (converts to Array)
    status_filtered_teammates = query.filter_by_status(filtered_teammates)
    
    # Paginate the status-filtered teammates using Kaminari-style pagination
    @pagy = Pagy.new(count: status_filtered_teammates.count, page: params[:page] || 1, items: 25)
    @teammates = status_filtered_teammates[@pagy.offset, @pagy.items]
    
    # Eager load associations for check-in status display
    if query.current_view == 'check_in_status'
      @teammates = eager_load_check_in_data(@teammates)
    end
    
    # Calculate spotlight statistics from all teammates (not filtered, not paginated)
    all_teammates = query.call
    @spotlight_stats = calculate_spotlight_stats(all_teammates)
    
    # Use manager spotlight if manager filter is active
    @spotlight_type = params[:manager_filter] == 'direct_reports' ? 'manager_overview' : 'teammates_overview'
    
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
    
    # Separate acknowledged and pending snapshots for employee view
    if current_person == @person
      @acknowledged_snapshots = @maap_snapshots.where.not(employee_acknowledged_at: nil)
      @pending_snapshots = @maap_snapshots.where(employee_acknowledged_at: nil).where.not(effective_date: nil)
    end
  end
  
  def acknowledge_snapshots
    # Find the person/employee
    @person = @organization.employees.find(params[:id])
    
    # Authorize access to audit view
    authorize @person, :audit?
    
    # Only allow employees to acknowledge their own snapshots
    unless current_person == @person
      redirect_to audit_organization_employee_path(@organization, @person), 
                  alert: 'You can only acknowledge your own check-ins.'
      return
    end
    
    # Get selected snapshot IDs
    snapshot_ids = params[:snapshot_ids] || []
    
    if snapshot_ids.empty?
      redirect_to audit_organization_employee_path(@organization, @person), 
                  alert: 'Please select at least one check-in to acknowledge.'
      return
    end
    
    # Find and acknowledge the snapshots
    snapshots = MaapSnapshot.where(id: snapshot_ids, employee: @person).where.not(effective_date: nil)
    
    acknowledged_count = 0
    snapshots.each do |snapshot|
      unless snapshot.acknowledged?
        snapshot.update!(
          employee_acknowledged_at: Time.current,
          employee_acknowledgement_request_info: {
            acknowledged_by: current_person.id,
            acknowledged_at: Time.current,
            request_source: 'audit_page'
          }
        )
        acknowledged_count += 1
      end
    end
    
    redirect_to audit_organization_employee_path(@organization, @person), 
                notice: "Successfully acknowledged #{acknowledged_count} check-in#{'s' if acknowledged_count != 1}."
  end
  
  private

    def eager_load_check_in_data(teammates)
      # Convert array back to ActiveRecord relation for eager loading if needed
      if teammates.is_a?(Array)
        teammate_ids = teammates.map(&:id)
        teammates_relation = Teammate.where(id: teammate_ids)
      else
        teammates_relation = teammates
      end
      
      # Eager load all check-in related associations
      teammates_relation.includes(
        :person,
        :employment_tenures => [:position_check_ins, :position],
        :assignment_tenures => [:assignment_check_ins, :assignment],
        :aspiration_check_ins => :aspiration,
        :teammate_milestones => :ability
      )
    end

    def calculate_spotlight_stats(teammates)
      # Always use ActiveRecord relation for spotlight stats to ensure proper joins
      if teammates.is_a?(Array)
        # Convert Array back to ActiveRecord relation for proper joins
        teammate_ids = teammates.map(&:id)
        teammates_relation = Teammate.where(id: teammate_ids)
      else
        teammates_relation = teammates
      end

      base_stats = {
        total_teammates: teammates.count,
        followers: teammates.select { |t| TeammateStatus.new(t).status == :follower }.count,
        huddlers: teammates.select { |t| TeammateStatus.new(t).status == :huddler }.count,
        unassigned_employees: teammates.select { |t| TeammateStatus.new(t).status == :unassigned_employee }.count,
        assigned_employees: teammates.select { |t| TeammateStatus.new(t).status == :assigned_employee }.count,
        terminated: teammates.select { |t| TeammateStatus.new(t).status == :terminated }.count,
        unknown: teammates.select { |t| TeammateStatus.new(t).status == :unknown }.count,
        huddle_participants: teammates_relation.joins(:huddle_participants).distinct.count,
        non_employee_participants: teammates_relation.joins(:huddle_participants).where(first_employed_at: nil).distinct.count
      }

      # Add manager-specific stats if this is a manager view
      if params[:manager_filter] == 'direct_reports' && current_person
        manager_stats = calculate_manager_stats(teammates, teammates_relation)
        base_stats.merge(manager_stats)
      else
        base_stats
      end
    end

    def calculate_manager_stats(teammates, teammates_relation)
      total_direct_reports = teammates.count
      ready_for_finalization = 0
      needs_manager_completion = 0
      pending_acknowledgements = 0
      total_check_ins = 0

      teammates.each do |teammate|
        # Count check-ins ready for finalization
        ready_count = ready_for_finalization_count(teammate.person, @organization)
        ready_for_finalization += ready_count

        # Count check-ins needing manager completion
        check_ins = check_ins_for_employee(teammate.person, @organization)
        needs_manager_completion += check_ins[:needs_manager_completion].count
        total_check_ins += check_ins[:position].count + check_ins[:assignments].count + check_ins[:aspirations].count

        # Count pending acknowledgements
        pending_acknowledgements += pending_acknowledgements_count(teammate.person, @organization)
      end

      # Calculate percentages
      completion_percentage = total_check_ins > 0 ? ((total_check_ins - needs_manager_completion - ready_for_finalization) * 100.0 / total_check_ins).round(1) : 0
      ready_percentage = total_check_ins > 0 ? (ready_for_finalization * 100.0 / total_check_ins).round(1) : 0
      incomplete_percentage = total_check_ins > 0 ? (needs_manager_completion * 100.0 / total_check_ins).round(1) : 0

      # Calculate team health score (simplified)
      team_health_score = if total_direct_reports > 0
        completion_rate = completion_percentage
        acknowledgement_rate = pending_acknowledgements > 0 ? 0 : 100
        ((completion_rate + acknowledgement_rate) / 2).round(0)
      else
        0
      end

      {
        total_direct_reports: total_direct_reports,
        ready_for_finalization: ready_for_finalization,
        needs_manager_completion: needs_manager_completion,
        pending_acknowledgements: pending_acknowledgements,
        total_check_ins: total_check_ins,
        completion_percentage: completion_percentage,
        ready_percentage: ready_percentage,
        incomplete_percentage: incomplete_percentage,
        team_health_score: team_health_score
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
