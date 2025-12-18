class Organizations::PublicMaap::DepartmentsController < Organizations::PublicMaap::BaseController
  def show
    @department = Organization.find_by_param(params[:id])
    
    unless @department
      raise ActiveRecord::RecordNotFound, "Department not found"
    end
    
    # Verify the department belongs to the organization's hierarchy
    company = @organization.root_company || @organization
    unless company.self_and_descendants.map(&:id).include?(@department.id)
      raise ActiveRecord::RecordNotFound, "Department not found"
    end
    
    # Get all departments in scope (this department and its descendants)
    departments_in_scope = @department.self_and_descendants.select { |org| org.department? || org.company? }
    department_ids = departments_in_scope.map(&:id)
    
    # Load positions where position_type.organization is in the department scope (directly linked)
    @positions_direct = Position
      .joins(position_type: :organization)
      .where(organizations: { id: department_ids })
      .includes(position_type: :organization, position_level: :position_major_level)
      .ordered
    
    # Load positions where organization is the department's parent company (indirectly linked)
    # These are positions that belong to the parent company but not specifically to the department
    parent_org = @department.parent
    if parent_org && parent_org.company?
      @positions_indirect = Position
        .joins(position_type: :organization)
        .where(organizations: { id: parent_org.id })
        .where.not(organizations: { id: department_ids })
        .includes(position_type: :organization, position_level: :position_major_level)
        .ordered
    else
      @positions_indirect = Position.none
    end
    
    # Load assignments where department field points to this department or its descendants (directly linked)
    @assignments_direct = Assignment
      .where(department_id: department_ids)
      .includes(:company, :department)
      .ordered
    
    # Load assignments where company is the department but department field is nil or not in scope (indirectly linked)
    @assignments_indirect = Assignment
      .where(company_id: department_ids)
      .where.not(department_id: department_ids)
      .includes(:company, :department)
      .ordered
    
    # Load abilities where organization is in scope (directly linked)
    @abilities_direct = Ability
      .where(organization_id: department_ids)
      .ordered
    
    # Load abilities where organization is the department's parent company (indirectly linked)
    if parent_org && parent_org.company?
      @abilities_indirect = Ability
        .where(organization_id: parent_org.id)
        .where.not(organization_id: department_ids)
        .ordered
    else
      @abilities_indirect = Ability.none
    end
  end
end

