# frozen_string_literal: true

module Goals
  # Active personal goals owned by the given report CompanyTeammate ids,
  # optionally limited to goals the viewer can see via Goal#can_be_viewed_by?.
  class EmployeeOwnedGoalsQuery
    def self.call(relation:, owner_ids:, viewer_person: nil)
      new(relation: relation, owner_ids: owner_ids, viewer_person: viewer_person).call
    end

    def self.direct_report_ids(manager:, organization:)
      return [] unless manager && organization

      company = organization.company? ? organization : (organization.root_company || organization)
      EmploymentTenure
        .where(company: company, manager_teammate: manager, ended_at: nil)
        .pluck(:teammate_id)
    end

    def self.hierarchy_report_ids(manager:, organization:)
      return [] unless manager && organization

      CompanyTeammate
        .self_and_reporting_hierarchy(manager, organization)
        .where.not(id: manager.id)
        .pluck(:id)
    end

    def initialize(relation:, owner_ids:, viewer_person: nil)
      @relation = relation
      @owner_ids = Array(owner_ids).compact
      @viewer_person = viewer_person
    end

    def call
      return @relation.none if @owner_ids.empty?

      scoped = @relation.active.where(owner_type: "CompanyTeammate", owner_id: @owner_ids)
      return scoped unless @viewer_person

      visible_ids = scoped.select { |goal| goal.can_be_viewed_by?(@viewer_person) }.map(&:id)
      scoped.where(id: visible_ids)
    end
  end
end
