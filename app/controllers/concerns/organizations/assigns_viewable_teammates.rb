# frozen_string_literal: true

module Organizations
  # Loads teammates the current viewer may switch to in header UX (dropdown grouped by department).
  # Sets @selected_teammate, @viewable_teammates, @viewable_teammate_groups.
  #
  # Requires: #organization, #current_company_teammate, Pundit #policy helpers (same as
  # Organizations::OrganizationNamespaceBaseController).
  #
  # Call after the resource teammate is known, e.g. assign_viewable_teammates_context!(selected_teammate: @teammate)
  module AssignsViewableTeammates
    extend ActiveSupport::Concern

    private

    def assign_viewable_teammates_context!(selected_teammate:)
      @selected_teammate = selected_teammate
      @viewable_teammates = load_viewable_teammates_relation.to_a
      @viewable_teammate_groups = group_viewable_teammates_by_department(@viewable_teammates)
    end

    def load_viewable_teammates_relation
      base_scope = CompanyTeammate
        .for_organization_hierarchy(organization)
        .joins(:person)
        .includes(:person, employment_tenures: { position: { title: :department } })
        .where(last_terminated_at: nil)

      if policy(organization).manage_employment?
        base_scope.order('people.last_name ASC NULLS LAST, people.first_name ASC, people.preferred_name ASC NULLS LAST')
      else
        CompanyTeammate
          .self_and_reporting_hierarchy(current_company_teammate, organization)
          .joins(:person)
          .includes(:person, employment_tenures: { position: { title: :department } })
          .where(last_terminated_at: nil)
          .order('people.last_name ASC NULLS LAST, people.first_name ASC, people.preferred_name ASC NULLS LAST')
      end
    end

    def group_viewable_teammates_by_department(teammates)
      groups = teammates.group_by do |teammate|
        active_tenure = teammate.employment_tenures.find do |tenure|
          tenure.ended_at.nil? && tenure.company_id == organization.id
        end
        active_tenure&.position&.title&.department&.name.presence || 'No Department'
      end

      groups.sort_by { |department_name, _| department_name == 'No Department' ? "\uFFFF" : department_name.downcase }.to_h
    end
  end
end
