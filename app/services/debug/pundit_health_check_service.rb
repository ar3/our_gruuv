module Debug
  class PunditHealthCheckService
    def self.call(controller_context)
      new(controller_context).call
    end

    def initialize(controller_context)
      @controller = controller_context
      @session = controller_context.session
      @params = controller_context.params
    end

    def call
      {
        organization_context: organization_context,
        impersonation_status: impersonation_status,
        teammate_details: teammate_details,
        pundit_user_structure: pundit_user_structure,
        managerial_hierarchy: managerial_hierarchy,
        policy_checks: policy_checks,
        caching_information: caching_information,
        session_data: session_data
      }
    end

    private

    attr_reader :controller, :session, :params

    def organization_context
      route_org_id = params[:organization_id] || params[:id]
      route_organization = Organization.find_by(id: route_org_id) if route_org_id

      org_from_params = route_org_id
      org_from_instance = controller.instance_variable_get(:@organization) if controller.instance_variable_defined?(:@organization)
      org_from_teammate = current_company_teammate&.organization

      org_from_helper = begin
        if controller.respond_to?(:organization)
          controller.organization
        end
      rescue => e
        "Error: #{e.message}"
      end

      simulated_actual_org = if route_organization&.is_a?(Organization)
        route_organization
      elsif current_person && pundit_user_struct
        begin
          policy = PersonPolicy.new(pundit_user_struct, current_person)
          policy.send(:actual_organization)
        rescue
          current_company_teammate&.organization
        end
      else
        current_company_teammate&.organization
      end

      {
        org_from_params: org_from_params,
        org_from_instance: org_from_instance,
        org_from_teammate: org_from_teammate,
        org_from_helper: org_from_helper,
        simulated_actual_org: simulated_actual_org,
        route_organization: route_organization
      }
    end

    def impersonation_status
      is_impersonating = session[:impersonating_teammate_id].present?
      impersonating_teammate_id = session[:impersonating_teammate_id]
      impersonating_teammate = if controller.respond_to?(:impersonating_teammate)
        controller.impersonating_teammate
      end
      current_teammate = current_company_teammate

      impersonating_teammate_record = Teammate.find_by(id: impersonating_teammate_id) if impersonating_teammate_id
      session_teammate_record = Teammate.find_by(id: session[:current_company_teammate_id]) if session[:current_company_teammate_id]

      {
        is_impersonating: is_impersonating,
        impersonating_teammate_id: impersonating_teammate_id,
        impersonating_teammate: impersonating_teammate,
        current_teammate: current_teammate,
        impersonating_teammate_record: impersonating_teammate_record,
        session_teammate_record: session_teammate_record
      }
    end

    def teammate_details
      current_teammate = current_company_teammate

      if current_teammate
        current_teammate_id = current_teammate.id
        current_teammate_type = current_teammate.type
        current_teammate_org = current_teammate.organization
        current_teammate_permissions = {
          can_manage_employment: current_teammate.can_manage_employment?,
          can_create_employment: current_teammate.can_create_employment?,
          can_manage_maap: current_teammate.can_manage_maap?,
          can_manage_prompts: current_teammate.can_manage_prompts?
        }

        current_person = current_teammate.person
        all_teammates = current_person.teammates.includes(:organization).map do |t|
          {
            id: t.id,
            type: t.type,
            organization_id: t.organization_id,
            organization_name: t.organization.name,
            can_manage_employment: t.can_manage_employment?,
            can_create_employment: t.can_create_employment?,
            can_manage_maap: t.can_manage_maap?,
            can_manage_prompts: t.can_manage_prompts?
          }
        end
      else
        current_teammate_id = nil
        current_teammate_type = nil
        current_teammate_org = nil
        current_teammate_permissions = nil
        current_person = nil
        all_teammates = []
      end

      session_teammate_id = session[:current_company_teammate_id]

      {
        current_teammate_id: current_teammate_id,
        current_teammate_type: current_teammate_type,
        current_teammate_org: current_teammate_org,
        current_teammate_permissions: current_teammate_permissions,
        current_person: current_person,
        all_teammates: all_teammates,
        session_teammate_id: session_teammate_id
      }
    end

    def pundit_user_structure
      pundit_user_struct = if controller.respond_to?(:pundit_user)
        controller.pundit_user
      end
      pundit_user_user = pundit_user_struct&.user if pundit_user_struct
      pundit_user_real_user = pundit_user_struct&.real_user if pundit_user_struct

      {
        pundit_user_struct: pundit_user_struct,
        pundit_user_user: pundit_user_user,
        pundit_user_real_user: pundit_user_real_user
      }
    end

    def managerial_hierarchy
      current_person = current_company_teammate&.person
      route_org_id = params[:organization_id] || params[:id]
      route_organization = Organization.find_by(id: route_org_id) if route_org_id

      if current_person && route_organization
        managers = ManagerialHierarchyQuery.new(person: current_person, organization: route_organization).call
        direct_reports = EmployeeHierarchyQuery.new(person: current_person, organization: route_organization).call
      else
        managers = []
        direct_reports = []
      end

      {
        managers: managers,
        direct_reports: direct_reports
      }
    end

    def policy_checks
      policy_checks = {}
      current_person = current_company_teammate&.person
      pundit_user_struct = if controller.respond_to?(:pundit_user)
        controller.pundit_user
      end

      if current_person && pundit_user_struct
        # Test view_check_ins? for current person
        begin
          policy = PersonPolicy.new(pundit_user_struct, current_person)
          policy_checks[:current_person] = {
            result: policy.view_check_ins?,
            error: nil,
            person_name: current_person.display_name
          }
        rescue => e
          policy_checks[:current_person] = {
            result: false,
            error: e.message,
            person_name: current_person.display_name
          }
        end

        # Test for each manager
        route_org_id = params[:organization_id] || params[:id]
        route_organization = Organization.find_by(id: route_org_id) if route_org_id

        if route_organization
          managers = ManagerialHierarchyQuery.new(person: current_person, organization: route_organization).call
          managers.each do |manager_info|
            manager_person = Person.find_by(id: manager_info[:person_id])
            next unless manager_person

            begin
              policy = PersonPolicy.new(pundit_user_struct, manager_person)
              result = policy.view_check_ins?
              policy_checks["manager_#{manager_info[:person_id]}"] = {
                person_id: manager_info[:person_id],
                person_name: manager_info[:name],
                result: result,
                error: nil
              }
            rescue => e
              policy_checks["manager_#{manager_info[:person_id]}"] = {
                person_id: manager_info[:person_id],
                person_name: manager_info[:name],
                result: false,
                error: e.message
              }
            end
          end

          # Test for each direct report
          direct_reports = EmployeeHierarchyQuery.new(person: current_person, organization: route_organization).call
          direct_reports.each do |report_info|
            report_person = Person.find_by(id: report_info[:person_id])
            next unless report_person

            begin
              policy = PersonPolicy.new(pundit_user_struct, report_person)
              result = policy.view_check_ins?
              policy_checks["report_#{report_info[:person_id]}"] = {
                person_id: report_info[:person_id],
                person_name: report_info[:name],
                result: result,
                error: nil
              }
            rescue => e
              policy_checks["report_#{report_info[:person_id]}"] = {
                person_id: report_info[:person_id],
                person_name: report_info[:name],
                result: false,
                error: e.message
              }
            end
          end
        end
      end

      policy_checks
    end

    def caching_information
      teammate_cached = controller.instance_variable_defined?(:@current_company_teammate)
      cache_config = {
        store: Rails.cache.class.name,
        namespace: Rails.cache.respond_to?(:namespace) ? Rails.cache.namespace : 'N/A'
      }

      {
        teammate_cached: teammate_cached,
        cache_config: cache_config
      }
    end

    def session_data
      {
        current_company_teammate_id: session[:current_company_teammate_id],
        impersonating_teammate_id: session[:impersonating_teammate_id],
        all_keys: session.keys.grep(/teammate|person|organization/)
      }
    end

    def current_company_teammate
      controller.current_company_teammate if controller.respond_to?(:current_company_teammate)
    end

    def current_person
      current_company_teammate&.person
    end

    def pundit_user_struct
      controller.pundit_user if controller.respond_to?(:pundit_user)
    end
  end
end

