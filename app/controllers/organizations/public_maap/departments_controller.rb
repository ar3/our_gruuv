class Organizations::PublicMaap::DepartmentsController < Organizations::PublicMaap::BaseController
  def show
    @department = Department.find_by_param(params[:id])
    
    unless @department
      raise ActiveRecord::RecordNotFound, "Department not found"
    end
    
    # Verify the department belongs to this company
    company = @organization.company? ? @organization : @organization.root_company
    unless @department.company_id == company&.id
      raise ActiveRecord::RecordNotFound, "Department not found"
    end
    
    # Get all departments in scope (this department and its descendants)
    department_ids = @department.self_and_descendants.map(&:id)
    
    # Load positions where title.department is in the department scope
    @positions_direct = Position
      .joins(:title)
      .where(titles: { department_id: department_ids })
      .includes(title: [:company, :department], position_level: :position_major_level)
      .ordered
    
    # Load positions at company level (no department)
    @positions_indirect = Position
      .joins(:title)
      .where(titles: { company_id: company.id, department_id: nil })
      .includes(title: [:company, :department], position_level: :position_major_level)
      .ordered
    
    # Load assignments where department is in scope
    @assignments_direct = Assignment
      .where(department_id: department_ids)
      .includes(:company, :department)
      .ordered
    
    # Load assignments at company level (no department)
    @assignments_indirect = Assignment
      .where(company_id: company.id, department_id: nil)
      .includes(:company, :department)
      .ordered
    
    # Load abilities where department is in scope
    @abilities_direct = Ability
      .where(department_id: department_ids)
      .ordered
    
    # Load abilities at company level (no department)
    @abilities_indirect = Ability
      .where(company_id: company.id, department_id: nil)
      .ordered
  end
end
