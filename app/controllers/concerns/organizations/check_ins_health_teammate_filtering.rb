# frozen_string_literal: true

# Shared "Who to show" filtering for check-ins health and acknowledgement nudge pages.
module Organizations
  module CheckInsHealthTeammateFiltering
    extend ActiveSupport::Concern

    private

    def apply_filter_default_if_needed
      return if params[:manager_id].present?

      params[:manager_id] = default_manager_filter_value
    end

    def default_manager_filter_value
      if policy(@organization).manage_employment?
        'everyone'
      elsif current_company_teammate&.has_direct_reports?
        'my_direct_employees'
      elsif current_company_teammate && hierarchy_count_excluding_self > 0
        'my_employees_full_hierarchy'
      else
        'just_me'
      end
    end

    def hierarchy_count_excluding_self
      return 0 unless current_company_teammate && @organization

      ids = CompanyTeammate.self_and_reporting_hierarchy(current_company_teammate, @organization).pluck(:id)
      ids.size > 1 ? ids.size - 1 : 0
    end

    def filtered_teammates_for_check_ins_health
      base_scope = CompanyTeammate.for_organization_hierarchy(@organization)
        .where.not(first_employed_at: nil)
        .where(last_terminated_at: nil)
        .includes(:person, :employment_tenures, :organization)
        .joins(:person)
        .order('people.last_name ASC, people.first_name ASC')

      case params[:manager_id].to_s
      when 'everyone'
        return base_scope if policy(@organization).manage_employment?

        viewing_teammate = base_scope.find_by(person: current_person)
        if viewing_teammate
          hierarchy_ids = CompanyTeammate.self_and_reporting_hierarchy(viewing_teammate, @organization).pluck(:id)
          base_scope.where(id: hierarchy_ids)
        else
          base_scope.none
        end
      when 'my_direct_employees'
        return base_scope.none unless current_company_teammate&.has_direct_reports?

        direct_report_ids = EmploymentTenure
          .where(company: @organization, manager_teammate: current_company_teammate, ended_at: nil)
          .pluck(:teammate_id)
        base_scope.where(id: direct_report_ids)
      when 'my_employees_full_hierarchy'
        return base_scope.none unless current_company_teammate

        hierarchy_ids = CompanyTeammate.self_and_reporting_hierarchy(current_company_teammate, @organization).pluck(:id)
        base_scope.where(id: hierarchy_ids)
      when 'just_me'
        return base_scope.none unless current_company_teammate

        base_scope.where(id: current_company_teammate.id)
      else
        if params[:manager_id].to_s =~ /\ACompanyTeammate_(\d+)\z/
          manager_id = Regexp.last_match(1).to_i
          return base_scope.none unless manager_viewable?(manager_id)

          direct_report_ids = EmploymentTenure
            .where(company: @organization, manager_teammate_id: manager_id, ended_at: nil)
            .pluck(:teammate_id)
          base_scope.where(id: direct_report_ids)
        else
          params[:manager_id] = default_manager_filter_value
          filtered_teammates_for_check_ins_health
        end
      end
    end

    def manager_viewable?(manager_id)
      return true if policy(@organization).manage_employment?
      return false unless current_company_teammate

      hierarchy_ids = CompanyTeammate.self_and_reporting_hierarchy(current_company_teammate, @organization).pluck(:id)
      hierarchy_ids.include?(manager_id)
    end

    def available_check_ins_health_manager_filter_options
      company = @organization.root_company || @organization
      options = []
      options << ['Everyone', 'everyone'] if policy(@organization).manage_employment?
      options << ['My Direct Employees', 'my_direct_employees'] if current_company_teammate&.has_direct_reports?
      if current_company_teammate && hierarchy_count_excluding_self > 0
        options << ['My Employees (full hierarchy)', 'my_employees_full_hierarchy']
      end
      options << ['Just Me', 'just_me']
      manager_opts = visible_managers_for_check_ins_health(company)
      options.concat(manager_opts)
      options
    end

    def visible_managers_for_check_ins_health(company)
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
      teammates = CompanyTeammate.where(id: manager_teammate_ids).joins(:person).order('people.last_name ASC, people.first_name ASC')
      teammates.map { |t| ["Manager: #{t.person&.display_name}", "CompanyTeammate_#{t.id}"] }.reject { |pair| pair[0].blank? }
    end
  end
end
