# frozen_string_literal: true

module Goals
  # Goals related to a department tree:
  # - owned by the department or any descendant department
  # - owned by teams whose department is in that tree
  # - company-visible personal goals of people whose active title department is in that tree
  class RelatedToDepartmentQuery
    def self.call(relation:, department:)
      new(relation: relation, department: department).call
    end

    def initialize(relation:, department:)
      @relation = relation
      @department = department
    end

    def call
      return @relation.none unless @department

      dept_ids = @department.self_and_descendants.map(&:id)
      return @relation.none if dept_ids.empty?

      team_ids = Team.active.where(department_id: dept_ids).pluck(:id)
      teammate_ids = teammate_ids_for_department_tree(dept_ids)

      result = @relation.where(owner_type: "Department", owner_id: dept_ids)
      if team_ids.any?
        result = result.or(@relation.where(owner_type: "Team", owner_id: team_ids))
      end
      if teammate_ids.any?
        result = result.or(
          @relation.where(
            owner_type: "CompanyTeammate",
            owner_id: teammate_ids,
            privacy_level: "everyone_in_company"
          )
        )
      end
      result
    end

    private

    def teammate_ids_for_department_tree(dept_ids)
      EmploymentTenure.active
        .joins(position: :title)
        .where(titles: { department_id: dept_ids })
        .distinct
        .pluck(:teammate_id)
    end
  end
end
