# frozen_string_literal: true

module Insights
  # Headline averages + per-department counts for Departments Insights.
  class DepartmentsOverview
    DepartmentStat = Struct.new(
      :department,
      :label,
      :assignments_count,
      :abilities_count,
      :seats_count,
      keyword_init: true
    )

    Result = Struct.new(
      :departments_count,
      :average_assignments_per_department,
      :average_abilities_per_department,
      :average_seats_per_department,
      :department_stats,
      :chart_data,
      keyword_init: true
    )

    def self.call(organization:)
      new(organization: organization).call
    end

    def initialize(organization:)
      @organization = organization
    end

    def call
      departments = Department.for_company(organization).active.ordered.includes(:titles).to_a
      stats = departments.map { |department| build_stat(department) }
      count = stats.size

      Result.new(
        departments_count: count,
        average_assignments_per_department: average(stats.map(&:assignments_count), count),
        average_abilities_per_department: average(stats.map(&:abilities_count), count),
        average_seats_per_department: average(stats.map(&:seats_count), count),
        department_stats: stats,
        chart_data: chart_data_for(stats)
      )
    end

    private

    attr_reader :organization

    def build_stat(department)
      assignments_count = Assignment.unarchived.for_department(department).count
      abilities_count = Ability.unarchived.for_department(department).count
      seats_count = Seat.for_department(department).active.count

      DepartmentStat.new(
        department: department,
        label: department.display_name,
        assignments_count: assignments_count,
        abilities_count: abilities_count,
        seats_count: seats_count
      )
    end

    def average(values, count)
      return 0.0 if count.zero?

      (values.sum.to_f / count).round(1)
    end

    def chart_data_for(stats)
      {
        categories: stats.map(&:label),
        series: [
          { name: "Assignments", data: stats.map(&:assignments_count) },
          { name: "Abilities", data: stats.map(&:abilities_count) },
          { name: "Seats", data: stats.map(&:seats_count) }
        ]
      }
    end
  end
end
