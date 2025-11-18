# frozen_string_literal: true

module Debug
  # Service to gather comprehensive authorization debug information
  # for troubleshooting policy and permission issues
  class AuthorizationDebugService
    attr_reader :current_user, :subject_person, :organization, :session

    def initialize(current_user:, subject_person:, organization:, session:)
      @current_user = current_user
      @subject_person = subject_person
      @organization = organization
      @session = session
    end

    def gather_all_data
      {
        current_user: current_user_context,
        subject_person: subject_person_context,
        policies: policy_evaluations,
        permissions: permission_checks,
        warnings: detect_issues
      }
    end

    private

    def current_user_context
      {
        person: current_user,
        person_id: current_user&.id,
        person_email: current_user&.email,
        person_name: current_user&.full_name,
        current_organization: organization,
        current_organization_id: organization&.id,
        session_teammate_id: session[:current_company_teammate_id],
        impersonating: session[:impersonating_teammate_id].present?,
        impersonating_teammate_id: session[:impersonating_teammate_id],
        og_admin: current_user&.og_admin?
      }
    end

    def subject_person_context
      subject_teammates = subject_person.teammates.includes(:organization).to_a
      {
        person: subject_person,
        person_id: subject_person.id,
        person_email: subject_person.email,
        person_name: subject_person.full_name,
        teammates_count: subject_teammates.count,
        teammates: subject_teammates.map do |tm|
          {
            id: tm.id,
            type: tm.type,
            organization: tm.organization.name,
            organization_id: tm.organization_id,
            organization_type: tm.organization.type,
            can_manage_employment: tm.can_manage_employment?,
            can_create_employment: tm.can_create_employment?,
            can_manage_maap: tm.can_manage_maap?,
            first_employed_at: tm.first_employed_at,
            last_terminated_at: tm.last_terminated_at,
            employed: tm.employed?,
            terminated: tm.terminated?
          }
        end,
        employment_tenures: subject_person.employment_tenures.includes(:company).map do |et|
          {
            id: et.id,
            company: et.company.name,
            company_id: et.company_id,
            started_at: et.started_at,
            ended_at: et.ended_at,
            active: et.ended_at.nil?
          }
        end
      }
    end

    def policy_evaluations
      policy_methods = [
        :show?, :public?, :teammate?, :can_view_manage_mode?, :manager?,
        :employment_summary?, :view_employment_history?, :audit?,
        :manage_assignments?, :change_employment?, :change?,
        :choose_assignments?, :update_assignments?, :view_other_companies?,
        :view_check_ins?, :edit?, :update?, :create?, :destroy?,
        :connect_google_identity?, :disconnect_identity?,
        :can_impersonate?, :can_impersonate_anyone?
      ]

      results = {}
      policy_methods.each do |method|
        results[method] = evaluate_policy_method(method)
      end
      results
    end

    def evaluate_policy_method(method)
      # Create a mock pundit_user for policy evaluation
      pundit_user = OpenStruct.new(
        user: current_user.teammates.find_by(organization: organization),
        real_user: current_user.teammates.find_by(organization: organization)
      )
      
      policy_obj = PersonPolicy.new(pundit_user, subject_person)
      
      begin
        result = policy_obj.public_send(method)
        explanation = explain_policy(method)
        { result: result, explanation: explanation }
      rescue => e
        { result: 'ERROR', explanation: "Error: #{e.message}\n#{e.backtrace.first(3).join("\n")}" }
      end
    end

    def explain_policy(method)
      explanations = []

      # Check admin bypass first
      if current_user&.og_admin?
        explanations << "✓ User is og_admin (bypasses all checks)"
        return explanations.join("\n")
      end

      # Check if viewing own profile
      if current_user == subject_person
        explanations << "✓ User is viewing their own profile (allowed for most actions)"
      else
        explanations << "✗ User is NOT viewing their own profile"
      end

      # Method-specific explanations that match the actual policy code
      case method
      when :show?
        explain_show_policy(explanations)
      when :teammate?
        explain_teammate_policy(explanations)
      when :manager?
        explain_manager_policy(explanations)
      when :view_check_ins?
        explain_view_check_ins_policy(explanations)
      when :manage_assignments?
        explain_manage_assignments_policy(explanations)
      when :can_view_manage_mode?
        explain_can_view_manage_mode_policy(explanations)
      when :view_employment_history?
        explain_view_employment_history_policy(explanations)
      when :change_employment?
        explain_change_employment_policy(explanations)
      when :audit?
        explain_audit_policy(explanations)
      else
        explanations << "No detailed explanation available for #{method}"
      end

      explanations.join("\n")
    end

    def explain_show_policy(explanations)
      # From PersonPolicy#show? - checks employment tenures for companies
      user_employment_orgs = current_user.employment_tenures.includes(:company).map(&:company)
      
      explanations << "\nChecking employment management in organizations where user has employment tenures:"
      user_employment_orgs.each do |org|
        has_employment = current_user.can_manage_employment?(org)
        has_maap = current_user.can_manage_maap?(org)
        if has_employment || has_maap
          explanations << "  ✓ #{org.name}: employment=#{has_employment}, maap=#{has_maap}"
        else
          explanations << "  ✗ #{org.name}: employment=#{has_employment}, maap=#{has_maap}"
        end
      end
      
      explanations << "\nResult: Allowed if user has employment OR maap management in ANY organization"
    end

    def explain_teammate_policy(explanations)
      # From PersonPolicy#teammate? - checks active employment in specific org
      explanations << "\nChecking teammate? policy for organization: #{organization&.name}"
      
      unless organization
        explanations << "  ✗ No organization context available"
        return
      end

      # Check if viewer is active in org
      viewer_active = current_user.active_employment_tenure_in?(organization)
      if viewer_active
        explanations << "  ✓ Viewer has active employment tenure in #{organization.name}"
      else
        explanations << "  ✗ Viewer does NOT have active employment tenure in #{organization.name}"
        explanations << "    (Checked: employment_tenures.active.where(company: #{organization.name}).exists?)"
      end

      # Check if subject has employment in org
      subject_has_employment = subject_person.employment_tenures.where(company: organization).exists?
      if subject_has_employment
        explanations << "  ✓ Subject has employment tenure in #{organization.name}"
      else
        explanations << "  ✗ Subject does NOT have employment tenure in #{organization.name}"
      end

      explanations << "\nResult: Allowed if BOTH viewer is active AND subject has employment in org"
    end

    def explain_manager_policy(explanations)
      # From PersonPolicy#manager? - checks teammates (not employment_tenures!)
      user_orgs = current_user.teammates.includes(:organization).map(&:organization)
      
      explanations << "\nChecking manager? policy - uses teammates (not employment_tenures!):"
      explanations << "Step 1: Check employment management in organizations where user has teammates:"
      
      has_employment_anywhere = false
      user_orgs.each do |org|
        has_employment = current_user.can_manage_employment?(org)
        if has_employment
          explanations << "  ✓ #{org.name}: can_manage_employment=true"
          has_employment_anywhere = true
        else
          explanations << "  ✗ #{org.name}: can_manage_employment=false"
        end
      end
      
      if has_employment_anywhere
        explanations << "\n✓ User has employment management in at least one organization (ALLOWED)"
        return
      end

      explanations << "\nStep 2: Check managerial hierarchy in employment orgs:"
      user_employment_orgs = current_user.employment_tenures.includes(:company).map(&:company)
      in_hierarchy = false
      user_employment_orgs.each do |org|
        is_in_hierarchy = current_user.in_managerial_hierarchy_of?(subject_person, org)
        if is_in_hierarchy
          explanations << "  ✓ #{org.name}: User is in managerial hierarchy"
          in_hierarchy = true
        else
          explanations << "  ✗ #{org.name}: User is NOT in managerial hierarchy"
        end
      end

      if in_hierarchy
        explanations << "\n✓ User is in managerial hierarchy (ALLOWED)"
      else
        explanations << "\n✗ User is NOT in managerial hierarchy (DENIED)"
      end
    end

    def explain_view_check_ins_policy(explanations)
      explanations << "\nChecking view_check_ins? policy:"
      
      if organization
        explanations << "Organization context: #{organization.name}"
        
        # Check managerial hierarchy
        is_in_hierarchy = current_user.in_managerial_hierarchy_of?(subject_person, organization)
        if is_in_hierarchy
          explanations << "  ✓ User is in managerial hierarchy for #{organization.name}"
          return
        else
          explanations << "  ✗ User is NOT in managerial hierarchy for #{organization.name}"
        end
        
        # Check employment management
        has_employment = current_user.can_manage_employment?(organization)
        if has_employment
          explanations << "  ✓ User has employment management in #{organization.name}"
        else
          explanations << "  ✗ User does NOT have employment management in #{organization.name}"
        end
      else
        explanations << "No organization context - checking shared organizations"
        user_orgs = current_user.teammates.map(&:organization)
        subject_orgs = subject_person.teammates.map(&:organization)
        shared_orgs = user_orgs & subject_orgs
        
        explanations << "Shared organizations: #{shared_orgs.map(&:name).join(', ')}"
        shared_orgs.each do |org|
          in_hierarchy = current_user.in_managerial_hierarchy_of?(subject_person, org)
          has_employment = current_user.can_manage_employment?(org)
          explanations << "  #{org.name}: hierarchy=#{in_hierarchy}, employment=#{has_employment}"
        end
      end
    end

    def explain_manage_assignments_policy(explanations)
      # From PersonPolicy#manage_assignments? - requires BOTH permissions
      explanations << "\nChecking manage_assignments? policy (requires BOTH employment AND maap):"
      
      # Check managerial hierarchy first
      user_employment_orgs = current_user.employment_tenures.includes(:company).map(&:company)
      explanations << "Step 1: Check managerial hierarchy:"
      in_hierarchy = false
      user_employment_orgs.each do |org|
        is_in_hierarchy = current_user.in_managerial_hierarchy_of?(subject_person, org)
        if is_in_hierarchy
          explanations << "  ✓ #{org.name}: User is in managerial hierarchy (ALLOWED)"
          in_hierarchy = true
        else
          explanations << "  ✗ #{org.name}: User is NOT in managerial hierarchy"
        end
      end
      
      return if in_hierarchy
      
      # Check for both permissions
      explanations << "\nStep 2: Check for BOTH employment AND maap permissions:"
      user_employment_orgs.each do |org|
        has_employment = current_user.can_manage_employment?(org)
        has_maap = current_user.can_manage_maap?(org)
        has_both = has_employment && has_maap
        
        if has_both
          explanations << "  ✓ #{org.name}: BOTH permissions (employment=#{has_employment}, maap=#{has_maap})"
        else
          explanations << "  ✗ #{org.name}: Missing permissions (employment=#{has_employment}, maap=#{has_maap})"
        end
      end
    end

    def explain_can_view_manage_mode_policy(explanations)
      # From PersonPolicy#can_view_manage_mode?
      explanations << "\nChecking can_view_manage_mode? policy:"
      
      # Check managerial hierarchy
      user_employment_orgs = current_user.employment_tenures.includes(:company).map(&:company)
      explanations << "Step 1: Check managerial hierarchy:"
      user_employment_orgs.each do |org|
        is_in_hierarchy = current_user.in_managerial_hierarchy_of?(subject_person, org)
        if is_in_hierarchy
          explanations << "  ✓ #{org.name}: User is in managerial hierarchy (ALLOWED)"
          return
        else
          explanations << "  ✗ #{org.name}: User is NOT in managerial hierarchy"
        end
      end
      
      # Check employment management
      explanations << "\nStep 2: Check employment management permissions:"
      user_employment_orgs.each do |org|
        has_employment = current_user.can_manage_employment?(org)
        if has_employment
          explanations << "  ✓ #{org.name}: can_manage_employment=true"
        else
          explanations << "  ✗ #{org.name}: can_manage_employment=false"
        end
      end
    end

    def explain_view_employment_history_policy(explanations)
      explain_can_view_manage_mode_policy(explanations) # Same logic
    end

    def explain_change_employment_policy(explanations)
      # From PersonPolicy#change_employment? - users cannot change their own employment unless they have manage employment permission
      explanations << "\nChecking change_employment? policy:"
      
      # Check if viewing own profile
      if current_user == subject_person
        explanations << "Step 1: User is viewing their own profile"
        explanations << "  ⚠ Viewing own profile is NOT sufficient - need manage employment permission to change own employment"
      else
        explanations << "Step 1: User is NOT viewing their own profile"
      end
      
      # Check managerial hierarchy first (applies to others)
      user_employment_orgs = current_user.employment_tenures.includes(:company).map(&:company)
      explanations << "\nStep 2: Check managerial hierarchy (allows changing others' employment):"
      in_hierarchy = false
      user_employment_orgs.each do |org|
        is_in_hierarchy = current_user.in_managerial_hierarchy_of?(subject_person, org)
        if is_in_hierarchy
          explanations << "  ✓ #{org.name}: User is in managerial hierarchy (ALLOWED)"
          in_hierarchy = true
        else
          explanations << "  ✗ #{org.name}: User is NOT in managerial hierarchy"
        end
      end
      
      return if in_hierarchy
      
      # Check employment management (applies to both own and others)
      explanations << "\nStep 3: Check employment management permissions (allows changing own or others' employment):"
      has_employment_anywhere = false
      user_employment_orgs.each do |org|
        has_employment = current_user.can_manage_employment?(org)
        if has_employment
          explanations << "  ✓ #{org.name}: can_manage_employment=true (ALLOWED)"
          has_employment_anywhere = true
        else
          explanations << "  ✗ #{org.name}: can_manage_employment=false"
        end
      end
      
      if !has_employment_anywhere && current_user == subject_person
        explanations << "\n✗ Result: User cannot change their own employment without manage employment permission (DENIED)"
      elsif !has_employment_anywhere
        explanations << "\n✗ Result: User does not have manage employment permission and is not in managerial hierarchy (DENIED)"
      end
    end

    def explain_audit_policy(explanations)
      # From PersonPolicy#audit? - uses specific organization and checks MAAP
      explanations << "\nChecking audit? policy (requires MAAP management in specific org):"
      
      unless organization
        explanations << "  ✗ No organization context available"
        return
      end
      
      explanations << "Organization: #{organization.name}"
      
      # Check managerial hierarchy
      is_in_hierarchy = current_user.in_managerial_hierarchy_of?(subject_person, organization)
      if is_in_hierarchy
        explanations << "  ✓ User is in managerial hierarchy for #{organization.name} (ALLOWED)"
        return
      else
        explanations << "  ✗ User is NOT in managerial hierarchy for #{organization.name}"
      end
      
      # Check MAAP management
      has_maap = current_user.can_manage_maap?(organization)
      if has_maap
        explanations << "  ✓ User has MAAP management in #{organization.name} (ALLOWED)"
      else
        explanations << "  ✗ User does NOT have MAAP management in #{organization.name} (DENIED)"
      end
    end

    def permission_checks
      viewer_orgs = current_user.teammates.includes(:organization).map(&:organization).uniq
      subject_orgs = subject_person.teammates.includes(:organization).map(&:organization).uniq

      {
        viewer_permissions: viewer_permissions_by_org(viewer_orgs),
        subject_permissions: subject_permissions_by_org(subject_orgs),
        hierarchy_checks: hierarchy_checks_for_org
      }
    end

    def viewer_permissions_by_org(orgs)
      permissions = {}
      orgs.each do |org|
        teammate_record = current_user.teammates.find_by(organization: org)
        permissions[org.name] = {
          organization_id: org.id,
          organization_type: org.type,
          teammate_id: teammate_record&.id,
          can_manage_employment: current_user.can_manage_employment?(org),
          can_create_employment: current_user.can_create_employment?(org),
          can_manage_maap: current_user.can_manage_maap?(org),
          can_manage_employment_hierarchy: Teammate.can_manage_employment_in_hierarchy?(current_user, org),
          can_manage_maap_hierarchy: Teammate.can_manage_maap_in_hierarchy?(current_user, org),
          teammate_flags: {
            can_manage_employment: teammate_record&.can_manage_employment?,
            can_create_employment: teammate_record&.can_create_employment?,
            can_manage_maap: teammate_record&.can_manage_maap?
          }
        }
      end
      permissions
    end

    def subject_permissions_by_org(orgs)
      permissions = {}
      orgs.each do |org|
        teammate_record = subject_person.teammates.find_by(organization: org)
        permissions[org.name] = {
          organization_id: org.id,
          organization_type: org.type,
          teammate_id: teammate_record&.id,
          can_manage_employment: subject_person.can_manage_employment?(org),
          can_create_employment: subject_person.can_create_employment?(org),
          can_manage_maap: subject_person.can_manage_maap?(org),
          teammate_flags: {
            can_manage_employment: teammate_record&.can_manage_employment?,
            can_create_employment: teammate_record&.can_create_employment?,
            can_manage_maap: teammate_record&.can_manage_maap?
          }
        }
      end
      permissions
    end

    def hierarchy_checks_for_org
      return {} unless organization

      {
        organization.name => {
          parent: organization.parent&.name,
          parent_id: organization.parent_id,
          self_and_descendants: organization.respond_to?(:self_and_descendants) ? 
            organization.self_and_descendants.pluck(:id, :name) : 
            [[organization.id, organization.name]],
          viewer_in_hierarchy: current_user.in_managerial_hierarchy_of?(subject_person, organization)
        }
      }
    end

    def detect_issues
      warnings = []

      # Check for Postgres version
      begin
        pg_version = ActiveRecord::Base.connection.execute("SELECT version()").first['version']
        if pg_version =~ /PostgreSQL (\d+)/
          version = $1.to_i
          warnings << {
            type: 'info',
            message: "PostgreSQL version: #{version}",
            details: "Local and production versions should match. Production is likely PostgreSQL 16."
          }
        end
      rescue => e
        warnings << {
          type: 'error',
          message: "Could not detect PostgreSQL version",
          details: e.message
        }
      end

      # Check for multiple teammates in same organization
      subject_teammates = subject_person.teammates.includes(:organization).to_a
      org_counts = subject_teammates.group_by(&:organization_id)
      org_counts.each do |org_id, teammates|
        if teammates.count > 1
          warnings << {
            type: 'warning',
            message: "Multiple teammate records for organization #{teammates.first.organization.name}",
            details: "Found #{teammates.count} teammate records (IDs: #{teammates.map(&:id).join(', ')}). This may cause unexpected behavior."
          }
        end
      end

      # Check for terminated teammates
      terminated = subject_teammates.select(&:terminated?)
      if terminated.any?
        warnings << {
          type: 'info',
          message: "Subject has #{terminated.count} terminated teammate record(s)",
          details: terminated.map { |t| "#{t.organization.name} (terminated: #{t.last_terminated_at})" }.join(', ')
        }
      end

      # Check for missing teammate in current organization
      if organization && !subject_teammates.any? { |t| t.organization_id == organization.id }
        warnings << {
          type: 'error',
          message: "Subject has NO teammate record in current organization (#{organization.name})",
          details: "This will cause authorization failures for organization-scoped checks. The teammate? policy will always return false."
        }
      end

      # Check if viewer has teammate in current organization
      if organization && current_user
        viewer_teammate = current_user.teammates.find_by(organization: organization)
        unless viewer_teammate
          warnings << {
            type: 'error',
            message: "Viewer has NO teammate record in current organization (#{organization.name})",
            details: "This will cause authorization failures. The viewer needs a teammate record in this organization."
          }
        end
      end

      warnings
    end
  end
end

