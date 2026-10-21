# frozen_string_literal: true

# Groups seats for header switcher dropdowns (department → alpha display name).
class SeatsByDepartmentForSwitcher
  def self.call(scope:)
    new(scope: scope).call
  end

  def initialize(scope:)
    @scope = scope
  end

  def call
    seats = @scope.includes(title: :department).joins(:title).left_joins(title: :department).order(
      Arel.sql("CASE WHEN titles.department_id IS NULL THEN 0 ELSE 1 END"),
      Arel.sql("COALESCE(departments.name, '')"),
      Arel.sql("LOWER(titles.external_title)"),
      Arel.sql("seats.seat_needed_by ASC")
    ).to_a

    grouped = seats.group_by { |seat| seat.title&.department }
    ordered = grouped.sort_by { |dept, _| dept ? [1, dept.display_name.to_s.downcase] : [0, ""] }.to_h
    ordered.transform_values { |list| list.sort_by { |s| [s.display_name.to_s.downcase, s.seat_needed_by || Date.today] } }
  end
end
