class Organizations::DepartmentsController < Organizations::OrganizationNamespaceBaseController
  before_action :require_authentication
  before_action :set_department, only: [
    :show, :edit, :update, :archive,
    :associate_abilities, :update_abilities_association,
    :associate_aspirations, :update_aspirations_association,
    :associate_titles, :update_titles_association,
    :associate_assignments, :update_assignments_association
  ]
  
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

  def index
    authorize @organization, :show?
    
    # Get all departments for this company
    @departments = Department.for_company(company).active.ordered
    
    # Build hierarchy tree
    @hierarchy_tree = build_department_hierarchy
  end

  def show
    authorize @department, :show?
    
    # Load child departments
    @child_departments = @department.child_departments.active.ordered
    # Preload child counts per department to avoid N+1 in view
    @child_department_counts_by_id = Department.where(parent_department_id: @child_departments.select(:id)).active.group(:parent_department_id).count
    
    # Load seats via titles with this department
    @seats_as_department = Seat.for_department(@department).includes(:title, employment_tenures: { company_teammate: :person })
    
    # Load titles for this department
    @titles = Title.for_department(@department).includes(:positions).ordered
    
    # Load assignments for this department
    @assignments = Assignment.for_department(@department).ordered
    
    # Load abilities for this department
    @abilities = Ability.for_department(@department).ordered
    
    # Load aspirations for this department
    @aspirations = Aspiration.for_department(@department).ordered
    
    # Load teams for the company (teams are company-wide, not department-specific)
    @teams = Team.for_company(company).active.ordered
  end

  def new
    @department = Department.new(company: company)
    
    # Set parent department if provided
    if params[:parent_department_id].present?
      @department.parent_department = Department.find(params[:parent_department_id])
    end
    
    authorize @department, :create?
    set_available_parents
  end

  def create
    @department = Department.new(department_params)
    @department.company = company
    authorize @department, :create?
    
    if @department.save
      redirect_to organization_departments_path(@organization), notice: 'Department was successfully created.'
    else
      set_available_parents
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @department, :update?
    set_available_parents
  end

  def update
    authorize @department, :update?
    
    # Prevent circular references
    update_params = department_params.dup
    if update_params[:parent_department_id].present?
      parent_id = update_params[:parent_department_id].to_i
      
      # Don't allow self as parent
      if parent_id == @department.id
        update_params.delete(:parent_department_id)
      # Don't allow descendants as parent
      elsif @department.descendants.map(&:id).include?(parent_id)
        update_params.delete(:parent_department_id)
      end
    end
    
    if @department.update(update_params)
      redirect_to organization_department_path(@organization, @department), notice: 'Department was successfully updated.'
    else
      set_available_parents
      render :edit, status: :unprocessable_entity
    end
  end

  def archive
    authorize @department, :archive?
    
    @department.soft_delete!
    redirect_to organization_departments_path(@organization), notice: 'Department was successfully archived.'
  end

  # Abilities association
  def associate_abilities
    authorize @department, :update?
    @unassociated_abilities = Ability.unarchived.for_company(company).where(department_id: nil).ordered
  end

  def update_abilities_association
    authorize @department, :update?
    
    ability_ids = params[:ability_ids] || []
    abilities_to_associate = Ability.unarchived.for_company(company).where(id: ability_ids, department_id: nil)
    
    count = abilities_to_associate.count
    abilities_to_associate.update_all(department_id: @department.id)
    
    redirect_to organization_department_path(@organization, @department), 
                notice: "#{count} #{'ability'.pluralize(count)} associated with #{@department.name}."
  end

  # Aspirations association
  def associate_aspirations
    authorize @department, :update?
    @unassociated_aspirations = Aspiration.for_company(company).where(department_id: nil).ordered
  end

  def update_aspirations_association
    authorize @department, :update?
    
    aspiration_ids = params[:aspiration_ids] || []
    aspirations_to_associate = Aspiration.for_company(company).where(id: aspiration_ids, department_id: nil)
    
    count = aspirations_to_associate.count
    aspirations_to_associate.update_all(department_id: @department.id)
    
    redirect_to organization_department_path(@organization, @department), 
                notice: "#{count} #{'aspiration'.pluralize(count)} associated with #{@department.name}."
  end

  # Titles association
  def associate_titles
    authorize @department, :update?
    @unassociated_titles = Title.for_company(company).where(department_id: nil).includes(:position_major_level).ordered
  end

  def update_titles_association
    authorize @department, :update?
    
    title_ids = params[:title_ids] || []
    titles_to_associate = Title.for_company(company).where(id: title_ids, department_id: nil)
    
    count = titles_to_associate.count
    titles_to_associate.update_all(department_id: @department.id)
    
    redirect_to organization_department_path(@organization, @department), 
                notice: "#{count} #{'title'.pluralize(count)} associated with #{@department.name}."
  end

  # Assignments association
  def associate_assignments
    authorize @department, :update?
    @unassociated_assignments = Assignment.for_company(company).where(department_id: nil).ordered
  end

  def update_assignments_association
    authorize @department, :update?
    
    assignment_ids = params[:assignment_ids] || []
    assignments_to_associate = Assignment.for_company(company).where(id: assignment_ids, department_id: nil)
    
    count = assignments_to_associate.count
    assignments_to_associate.update_all(department_id: @department.id)
    
    redirect_to organization_department_path(@organization, @department), 
                notice: "#{count} #{'assignment'.pluralize(count)} associated with #{@department.name}."
  end

  private

  def set_department
    @department = Department.find_by_param(params[:id])
    raise ActiveRecord::RecordNotFound unless @department
    raise ActiveRecord::RecordNotFound unless @department.company_id == company.id
    raise ActiveRecord::RecordNotFound if @department.archived?
  end

  def department_params
    params.require(:department).permit(:name, :parent_department_id)
  end

  def set_available_parents
    # Get all departments for this company, excluding self and descendants
    all_departments = Department.for_company(company).active.ordered
    
    if @department.persisted?
      descendant_ids = @department.descendants.map(&:id)
      @available_parents = all_departments.reject { |d| d.id == @department.id || descendant_ids.include?(d.id) }
    else
      @available_parents = all_departments
    end
  end

  def build_department_hierarchy
    # Build a tree structure for display
    root_departments = Department.for_company(company).root_departments.active.ordered
    root_departments.map { |dept| build_node(dept) }
  end

  def build_node(department)
    {
      department: department,
      children: department.child_departments.active.ordered.map { |child| build_node(child) },
      departments_count: count_descendants(department, type: :department),
      depth: department.ancestry_depth
    }
  end

  def count_descendants(department, type: nil)
    department.descendants.count
  end

  def require_authentication
    unless current_person
      redirect_to root_path, alert: 'Please log in to access departments.'
    end
  end
  
  def record_not_found
    render file: Rails.root.join('public', '404.html'), status: :not_found, layout: false
  end
end
