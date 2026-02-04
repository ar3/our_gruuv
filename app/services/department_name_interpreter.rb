class DepartmentNameInterpreter
  attr_reader :department_name, :company, :department, :hierarchy_info, :valid, :error_message

  def initialize(department_name, company)
    @department_name = department_name.to_s.strip
    @company = company
    @department = nil
    @hierarchy_info = []
    @valid = true
    @error_message = nil
  end

  def interpret
    return nil if @department_name.blank?
    return nil unless @company
    return nil unless @company.is_a?(Organization)

    # If department name exactly matches company name (case-insensitive), return nil
    # This means the assignment belongs to the company directly, not a department
    if @department_name.strip.downcase == @company.name.downcase
      @department = nil
      return nil
    end

    # Split by ">" delimiter
    parts = @department_name.split('>').map(&:strip).reject(&:blank?)

    # If no delimiter found, treat as single department name
    if parts.length == 1
      dept_info = find_or_create_department_info(parts.first, @company)
      @hierarchy_info = [dept_info]
      @department = dept_info[:department]
      return @department
    end

    # First part must match company name (case-insensitive)
    first_part = parts.first
    unless first_part.downcase == @company.name.downcase
      # First level doesn't match company - invalid
      @valid = false
      @error_message = "First part '#{first_part}' does not match company name '#{@company.name}'"
      return nil
    end

    # Build hierarchy starting from company
    current_parent = @company
    @hierarchy_info = []
    parts[1..-1].each do |dept_name|
      dept_info = find_or_create_department_info(dept_name, current_parent)
      @hierarchy_info << dept_info
      current_parent = dept_info[:department]
    end

    @department = current_parent
  end

  # Preview method that returns hierarchy info without creating departments
  def preview
    return { valid: false, error_message: 'Department name is blank' } if @department_name.blank?
    return { valid: false, error_message: 'Company is required' } unless @company
    return { valid: false, error_message: 'Company must be an Organization' } unless @company.is_a?(Organization)

    # If department name exactly matches company name (case-insensitive), return nil
    if @department_name.strip.downcase == @company.name.downcase
      return { valid: true, department: nil, hierarchy_info: [] }
    end

    # Split by ">" delimiter
    parts = @department_name.split('>').map(&:strip).reject(&:blank?)

    # If no delimiter found, treat as single department name
    if parts.length == 1
      dept_info = preview_department_info(parts.first, @company)
      return {
        valid: true,
        department: dept_info[:department],
        hierarchy_info: [dept_info]
      }
    end

    # First part must match company name (case-insensitive)
    first_part = parts.first
    unless first_part.downcase == @company.name.downcase
      return {
        valid: false,
        error_message: "First part '#{first_part}' does not match company name '#{@company.name}'"
      }
    end

    # Build hierarchy info starting from company
    current_parent = @company
    hierarchy_info = []
    parts[1..-1].each do |dept_name|
      dept_info = preview_department_info(dept_name, current_parent)
      hierarchy_info << dept_info
      # For next iteration, use the department if it exists, otherwise we'll need to track parent differently
      # Since we're in preview mode, we can't use the actual department object for the next parent
      # Instead, we'll use the parent parameter for the next call
      current_parent = dept_info[:department] || current_parent
    end

    # The final department is the last one in the hierarchy
    final_department = hierarchy_info.last&.dig(:department)

    {
      valid: true,
      department: final_department,
      hierarchy_info: hierarchy_info
    }
  end

  private

  def find_or_create_department(name, parent)
    dept_info = find_or_create_department_info(name, parent)
    dept_info[:department]
  end

  def find_or_create_department_info(name, parent)
    scope = department_scope_for_parent(parent)
    department = scope.find_by("LOWER(name) = ?", name.downcase)

    if department
      {
        name: name,
        department: department,
        will_create: false,
        existing_id: department.id
      }
    else
      attrs = parent.is_a?(Department) ? { company: parent.company, parent_department: parent } : { company: parent, parent_department: nil }
      new_dept = Department.create!(attrs.merge(name: name))
      {
        name: name,
        department: new_dept,
        will_create: true,
        existing_id: nil
      }
    end
  end

  def preview_department_info(name, parent)
    return {
      name: name,
      department: nil,
      will_create: true,
      existing_id: nil
    } unless parent.present?

    scope = department_scope_for_parent(parent)
    department = scope.find_by("LOWER(name) = ?", name.downcase)

    if department
      {
        name: name,
        department: department,
        will_create: false,
        existing_id: department.id
      }
    else
      {
        name: name,
        department: nil,
        will_create: true,
        existing_id: nil
      }
    end
  end

  def department_scope_for_parent(parent)
    if parent.is_a?(Department)
      Department.where(company: parent.company, parent_department_id: parent.id)
    else
      Department.where(company: parent, parent_department_id: nil)
    end
  end
end
