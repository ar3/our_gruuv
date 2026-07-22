# frozen_string_literal: true

# "Who to show" for Protect Flow — same scopes as health dashboards except
# never "everyone" (avoids forcing pagination on a card grid).
module Organizations
  module ProtectFlowTeammateFiltering
    extend ActiveSupport::Concern

    private

    def apply_protect_flow_filter_default_if_needed
      if params[:manager_id].blank? || params[:manager_id].to_s == "everyone"
        params[:manager_id] = default_protect_flow_manager_filter_value
      end
    end

    def default_protect_flow_manager_filter_value
      if current_company_teammate&.has_direct_reports?
        "my_direct_employees"
      elsif current_company_teammate && protect_flow_hierarchy_count_excluding_self.positive?
        "my_employees_full_hierarchy"
      else
        "just_me"
      end
    end

    def protect_flow_hierarchy_count_excluding_self
      return 0 unless current_company_teammate && @organization

      ids = CompanyTeammate.self_and_reporting_hierarchy(current_company_teammate, @organization).pluck(:id)
      ids.size > 1 ? ids.size - 1 : 0
    end

    def filtered_teammates_for_protect_flow
      base_scope = CompanyTeammate.for_organization_hierarchy(@organization)
        .where.not(first_employed_at: nil)
        .where(last_terminated_at: nil)
        .includes(:person, :teammate_identities, :employment_tenures, :organization)
        .joins(:person)
        .order("people.last_name ASC, people.first_name ASC")

      company = @organization.root_company || @organization

      case params[:manager_id].to_s
      when "everyone"
        params[:manager_id] = default_protect_flow_manager_filter_value
        filtered_teammates_for_protect_flow
      when "my_direct_employees"
        return base_scope.none unless current_company_teammate&.has_direct_reports?

        direct_report_ids = EmploymentTenure
          .where(company: company, manager_teammate: current_company_teammate, ended_at: nil)
          .pluck(:teammate_id)
        base_scope.where(id: direct_report_ids)
      when "my_employees_full_hierarchy"
        return base_scope.none unless current_company_teammate

        hierarchy_ids = CompanyTeammate.self_and_reporting_hierarchy(current_company_teammate, @organization).pluck(:id)
        # Exclude self — Protect Flow is about people you serve, not yourself
        hierarchy_ids -= [current_company_teammate.id]
        base_scope.where(id: hierarchy_ids)
      when "just_me"
        return base_scope.none unless current_company_teammate

        base_scope.where(id: current_company_teammate.id)
      else
        if params[:manager_id].to_s =~ /\ACompanyTeammate_(\d+)\z/
          manager_id = Regexp.last_match(1).to_i
          return base_scope.none unless protect_flow_manager_viewable?(manager_id)

          direct_report_ids = EmploymentTenure
            .where(company: company, manager_teammate_id: manager_id, ended_at: nil)
            .pluck(:teammate_id)
          base_scope.where(id: direct_report_ids)
        else
          params[:manager_id] = default_protect_flow_manager_filter_value
          filtered_teammates_for_protect_flow
        end
      end
    end

    def protect_flow_manager_viewable?(manager_id)
      return true if policy(@organization).manage_employment?
      return false unless current_company_teammate

      hierarchy_ids = CompanyTeammate.self_and_reporting_hierarchy(current_company_teammate, @organization).pluck(:id)
      hierarchy_ids.include?(manager_id)
    end

    def available_protect_flow_manager_filter_options
      company = @organization.root_company || @organization
      options = []
      options << ["My Direct Employees", "my_direct_employees"] if current_company_teammate&.has_direct_reports?
      if current_company_teammate && protect_flow_hierarchy_count_excluding_self.positive?
        options << ["My Employees (full hierarchy)", "my_employees_full_hierarchy"]
      end
      options << ["Just Me", "just_me"]
      options.concat(visible_managers_for_protect_flow(company))
      options
    end

    def visible_managers_for_protect_flow(company)
      if policy(@organization).manage_employment?
        manager_teammate_ids = EmploymentTenure
          .where(company: company, ended_at: nil)
          .where.not(manager_teammate_id: nil)
          .distinct
          .pluck(:manager_teammate_id)
      else
        return [] unless current_company_teammate

        hierarchy_ids = CompanyTeammate.self_and_reporting_hierarchy(current_company_teammate, @organization).pluck(:id)
        manager_teammate_ids = EmploymentTenure
          .where(company: company, ended_at: nil, manager_teammate_id: hierarchy_ids)
          .where.not(manager_teammate_id: nil)
          .distinct
          .pluck(:manager_teammate_id)
      end
      teammates = CompanyTeammate.where(id: manager_teammate_ids).joins(:person).order("people.last_name ASC, people.first_name ASC")
      teammates.map { |t| ["Manager: #{t.person&.display_name}", "CompanyTeammate_#{t.id}"] }.reject { |pair| pair[0].blank? }
    end
  end
end
