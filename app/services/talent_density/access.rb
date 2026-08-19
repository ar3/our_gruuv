# frozen_string_literal: true

module TalentDensity
  # Who a viewer may pick as "the manager on this page," and which directs they may rate.
  # Never includes the viewer's own teammate row.
  class Access
    def initialize(viewer:, organization:, org_wide:)
      @viewer = viewer
      @organization = organization
      @org_wide = org_wide
    end

    def selectable_managers
      ids = selectable_manager_ids
      return CompanyTeammate.none if ids.empty?

      CompanyTeammate.where(id: ids).joins(:person).includes(:person)
        .order("people.last_name ASC", "people.first_name ASC")
    end

    def manager_selectable?(manager)
      manager.present? && selectable_manager_ids.include?(manager.id)
    end

    def reports_for(manager)
      return CompanyTeammate.none unless manager_selectable?(manager)

      report_ids = EmploymentTenure
        .where(company: company, manager_teammate: manager, ended_at: nil)
        .pluck(:teammate_id)
      report_ids -= [viewer.id] if viewer

      CompanyTeammate.where(id: report_ids)
        .where.not(first_employed_at: nil)
        .where(last_terminated_at: nil)
        .joins(:person)
        .includes(:person, :talent_density_stance, employment_tenures: [:seat, { position: [:title, :position_level] }])
        .order("people.last_name ASC", "people.first_name ASC")
    end

    def can_edit?(subject)
      return false unless viewer && subject
      return false if subject.id == viewer.id
      return false unless subject.employed?

      manager = Goals::HealthManagerPerson.manager_teammate_for(subject, company: company)
      manager_selectable?(manager)
    end

    def default_manager
      managers = selectable_managers.to_a
      return nil if managers.empty?

      managers.find { |manager| manager.id == viewer.id } || managers.first
    end

    def viewers_for_subject(subject, manager: nil)
      manager ||= Goals::HealthManagerPerson.manager_teammate_for(subject, company: company)
      ids = ancestor_manager_ids(manager) + employment_manager_ids
      ids.delete(subject.id)
      return CompanyTeammate.none if ids.empty?

      CompanyTeammate.where(id: ids).joins(:person).includes(:person)
        .order("people.last_name ASC", "people.first_name ASC")
    end

    private

    attr_reader :viewer, :organization, :org_wide

    def company
      @company ||= organization.root_company || organization
    end

    def selectable_manager_ids
      @selectable_manager_ids ||= begin
        scope = EmploymentTenure.where(company: company, ended_at: nil).where.not(manager_teammate_id: nil)
        unless org_wide
          return [] unless viewer

          hierarchy_ids = CompanyTeammate.self_and_reporting_hierarchy(viewer, organization).pluck(:id)
          scope = scope.where(manager_teammate_id: hierarchy_ids)
        end
        scope.distinct.pluck(:manager_teammate_id)
      end
    end

    def ancestor_manager_ids(manager)
      ids = []
      current = manager
      seen = Set.new
      while current && seen.add?(current.id)
        ids << current.id
        current = Goals::HealthManagerPerson.manager_teammate_for(current, company: company)
      end
      ids
    end

    def employment_manager_ids
      @employment_manager_ids ||= CompanyTeammate
        .where(organization: organization, can_manage_employment: true)
        .where.not(first_employed_at: nil)
        .where(last_terminated_at: nil)
        .pluck(:id)
    end
  end
end
