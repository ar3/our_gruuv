# frozen_string_literal: true

# Groups unarchived assignments for header switcher dropdowns (department → alpha title).
class AssignmentsByDepartmentForSwitcher
  def self.call(scope:)
    new(scope: scope).call
  end

  def initialize(scope:)
    @scope = scope
  end

  def call
    assignments = @scope.unarchived.includes(:department).left_joins(:department).order(
      Arel.sql("CASE WHEN assignments.department_id IS NULL THEN 0 ELSE 1 END"),
      Arel.sql("COALESCE(departments.name, '')"),
      Arel.sql("LOWER(assignments.title)")
    ).to_a

    grouped = assignments.group_by(&:department)
    ordered = grouped.sort_by { |dept, _| dept ? [1, dept.display_name.to_s.downcase] : [0, ""] }.to_h
    ordered.transform_values { |list| list.sort_by { |a| a.title.to_s.downcase } }
  end
end
