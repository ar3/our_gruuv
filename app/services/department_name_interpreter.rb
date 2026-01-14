class DepartmentNameInterpreter
  attr_reader :department_name, :company, :department

  def initialize(department_name, company)
    @department_name = department_name.to_s.strip
    @company = company
    @department = nil
  end

  def interpret
    return nil if @department_name.blank?
    return nil unless @company&.company?

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
      @department = find_or_create_department(parts.first, @company)
      return @department
    end

    # First part must match company name (case-insensitive)
    first_part = parts.first
    unless first_part.downcase == @company.name.downcase
      # First level doesn't match company - treat entire string as single department
      @department = find_or_create_department(@department_name, @company)
      return @department
    end

    # Build hierarchy starting from company
    current_parent = @company
    parts[1..-1].each do |dept_name|
      current_parent = find_or_create_department(dept_name, current_parent)
    end

    @department = current_parent
  end

  private

  def find_or_create_department(name, parent)
    # Search within parent's descendants (including parent itself)
    org_ids = parent.self_and_descendants.map(&:id)
    
    # Find existing department by exact name match (case-insensitive)
    department = Organization.where(id: org_ids, type: 'Department')
                            .find_by("LOWER(name) = ?", name.downcase)

    if department
      department
    else
      # Create new department
      Organization.create!(
        name: name,
        parent: parent,
        type: 'Department'
      )
    end
  end
end
