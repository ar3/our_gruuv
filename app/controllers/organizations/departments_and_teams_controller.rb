class Organizations::DepartmentsAndTeamsController < Organizations::OrganizationNamespaceBaseController
  before_action :require_authentication
  before_action :set_department_or_team, only: [:show, :edit, :update, :archive]
  
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

  def index
    authorize @organization, :show?
    # Get all active descendants (departments and teams) with their hierarchy
    # descendants returns an array, so filter it
    all_descendants = @organization.descendants
    @departments_and_teams = all_descendants.select { |org| org.deleted_at.nil? }
    
    # Build hierarchy using query service
    query = DepartmentTeamHierarchyQuery.new(organization: @organization)
    @hierarchy_tree = query.call
    
    # Keep old hierarchy for table view (temporary, will be removed in Phase 4)
    @hierarchy = build_hierarchy(@organization)
  end

  def show
    authorize @department_or_team, :show?
    
    # Load direct children (descendants) - only active ones
    @descendants = @department_or_team.children.active.includes(:children).order(:type, :name)
    
    # Load seats with active employment tenures
    @seats = Seat.for_organization(@department_or_team).includes(:position_type, employment_tenures: { teammate: :person })
    
    # Load position types
    @position_types = @department_or_team.position_types.includes(:positions).ordered
    
    # Load assignments (where company or department matches)
    @assignments = Assignment.where(
      "(company_id = ? OR department_id = ?)",
      @department_or_team.id,
      @department_or_team.id
    ).ordered
    
    # Load abilities
    @abilities = @department_or_team.abilities.ordered
    
    # Load huddle playbooks
    @huddle_playbooks = @department_or_team.huddle_playbooks.includes(:huddles).order(:special_session_name)
  end

  def new
    @department_or_team = Organization.new
    @department_or_team.parent_id = params[:parent_id] || @organization.id
    @department_or_team.type = params[:type] if params[:type].present?
    authorize @department_or_team, :create?
  end

  def create
    @department_or_team = Organization.new(department_or_team_params)
    @department_or_team.parent_id ||= @organization.id
    authorize @department_or_team, :create?
    
    if @department_or_team.save
      redirect_to organization_departments_and_teams_path(@organization), notice: 'Department or team was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @department_or_team, :update?
    set_available_parents
  end

  def update
    authorize @department_or_team, :update?
    
    params_hash = department_or_team_params
    # Type cannot be changed - always use the current type
    params_hash[:type] = @department_or_team.type
    # Ensure parent_id is converted to integer if present
    params_hash[:parent_id] = params_hash[:parent_id].to_i if params_hash[:parent_id].present?
    
    # Prevent circular references - don't allow self or descendants as parent
    circular_reference_prevented = false
    if params_hash[:parent_id].present?
      if params_hash[:parent_id] == @department_or_team.id
        # Self as parent
        params_hash[:parent_id] = @department_or_team.parent_id
        circular_reference_prevented = true
      elsif @department_or_team.descendants.map(&:id).include?(params_hash[:parent_id])
        # Descendant as parent (would create circular reference)
        params_hash[:parent_id] = @department_or_team.parent_id
        circular_reference_prevented = true
      end
    end
    
    if @department_or_team.update(params_hash)
      redirect_path = organization_departments_and_team_path(@organization, @department_or_team)
      notice_message = if circular_reference_prevented
                         'Department or team was successfully updated. Note: The parent organization was not changed because it would create a circular reference.'
                       else
                         'Department or team was successfully updated.'
                       end
      redirect_to redirect_path, notice: notice_message
    else
      set_available_parents
      render :edit, status: :unprocessable_entity
    end
  end

  def archive
    authorize @department_or_team, :archive?
    
    @department_or_team.soft_delete!
    redirect_to organization_departments_and_teams_path(@organization), notice: 'Department or team was successfully archived.'
  end

  private

  def set_department_or_team
    # Extract ID from params (handles both "123" and "123-name" formats)
    id_from_params = params[:id].to_s.split('-').first.to_i
    return if id_from_params.zero? # Invalid ID
    
    # First, check if the organization exists and is archived (fail fast)
    # Use unscoped to find even archived records
    potential_org = Organization.unscoped.find_by(id: id_from_params)
    if potential_org
      # If it exists but is archived, raise error immediately
      if potential_org.deleted_at.present?
        raise ActiveRecord::RecordNotFound
      end
      # If it exists but is not in the organization's hierarchy, also raise error
      # Check if it's the organization itself or a descendant
      unless potential_org.id == @organization.id || @organization.descendants.map(&:id).include?(potential_org.id)
        raise ActiveRecord::RecordNotFound
      end
    end
    
    # Try to find in descendants first (descendants returns an array, already filtered for active)
    all_descendants = @organization.descendants
    @department_or_team = all_descendants.find { |org| org.id == id_from_params }
    
    # If not found, check if it's the organization itself (shouldn't happen for depts/teams, but handle gracefully)
    if !@department_or_team && @organization.id == id_from_params && @organization.deleted_at.nil?
      @department_or_team = @organization
    end
    
    raise ActiveRecord::RecordNotFound unless @department_or_team
  end

  def build_hierarchy(org, level = 0)
    children = org.children.active.includes(:children).order(:type, :name)
    result = []
    
    children.each do |child|
      result << {
        organization: child,
        level: level,
        children: build_hierarchy(child, level + 1)
      }
    end
    
    result
  end

  def department_or_team_params
    # Type is permitted for creation but cannot be changed after creation (see update action)
    # The form submits params using the model's param_key (e.g., :department or :team)
    # We need to handle both the model-specific key and :organization for backwards compatibility
    param_key = if params.key?(:department)
                  :department
                elsif params.key?(:team)
                  :team
                else
                  :organization
                end
    
    params.require(param_key).permit(:name, :type, :parent_id)
  end

  def set_available_parents
    # Get available parent organizations (company and all active descendants, excluding self and its descendants)
    available_parents = [@organization] + @organization.descendants.select { |org| org.deleted_at.nil? }
    # Exclude self and its descendants to prevent circular references
    filtered_parents = available_parents.reject { |org| org.id == @department_or_team.id || @department_or_team.descendants.map(&:id).include?(org.id) }
    # Order by type (Company=0, Department=1, Team=2) then by name
    @available_parents = filtered_parents.sort_by do |org|
      type_order = case org.type
                   when 'Company' then 0
                   when 'Department' then 1
                   when 'Team' then 2
                   else 3
                   end
      [type_order, org.name]
    end
  end

  def require_authentication
    unless current_person
      redirect_to root_path, alert: 'Please log in to access departments and teams.'
    end
  end
  
  def record_not_found
    render file: Rails.root.join('public', '404.html'), status: :not_found, layout: false
  end
end
