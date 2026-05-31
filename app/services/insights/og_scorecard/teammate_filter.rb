# frozen_string_literal: true

module Insights
  module OgScorecard
    # Resolves OG Scorecard teammate scope from department (position title) and manager checkboxes.
    # Uses current employment tenure for department and manager assignment across all weeks.
    class TeammateFilter
      MANAGER_PRESETS = %w[everyone my_direct_employees my_employees_full_hierarchy just_me].freeze

      def self.call(company:, current_company_teammate:, department_ids:, manager_ids:)
        new(
          company: company,
          current_company_teammate: current_company_teammate,
          department_ids: department_ids,
          manager_ids: manager_ids
        ).call
      end

      def self.available_departments(company)
        root = company.root_company || company
        Department.where(company: root).active.order(:name)
      end

      def self.available_manager_options(company:, current_company_teammate:)
        options = [['Everyone', 'everyone']]
        options << ['My Direct Employees', 'my_direct_employees']
        options << ['My Employees (full hierarchy)', 'my_employees_full_hierarchy']
        options << ['Just Me', 'just_me']

        manager_teammate_ids = EmploymentTenure
          .where(company: company, ended_at: nil)
          .where.not(manager_teammate_id: nil)
          .distinct
          .pluck(:manager_teammate_id)

        CompanyTeammate
          .where(id: manager_teammate_ids)
          .joins(:person)
          .order('people.last_name ASC', 'people.first_name ASC')
          .includes(:person)
          .find_each do |teammate|
            name = teammate.person&.display_name
            next if name.blank?

            options << ["Managed by #{name}", "CompanyTeammate_#{teammate.id}"]
          end

        options
      end

      def initialize(company:, current_company_teammate:, department_ids:, manager_ids:)
        @company = company
        @current_company_teammate = current_company_teammate
        @department_ids = Array(department_ids).map(&:to_s).reject(&:blank?)
        @manager_ids = Array(manager_ids).map(&:to_s).reject(&:blank?)
      end

      def active?
        department_filter_active? || manager_filter_active?
      end

      def call
        return nil unless active?

        ids = all_hierarchy_teammate_ids
        ids &= department_teammate_ids if department_filter_active?
        ids &= manager_teammate_ids_union if manager_filter_active?
        ids
      end

      private

      attr_reader :company, :current_company_teammate, :department_ids, :manager_ids

      def department_filter_active?
        department_ids.any?
      end

      def manager_filter_active?
        effective_manager_ids.any?
      end

      def effective_manager_ids
        manager_ids.reject { |id| id == 'everyone' }
      end

      def all_hierarchy_teammate_ids
        CompanyTeammate.for_organization_hierarchy(company).pluck(:id).to_set
      end

      def department_teammate_ids
        selected_dept_ids = department_ids.map(&:to_i).reject(&:zero?)
        include_none = department_ids.include?('none')
        return Set.new unless selected_dept_ids.any? || include_none

        ids = Set.new
        CompanyTeammate
          .for_organization_hierarchy(company)
          .includes(employment_tenures: { position: { title: :department } })
          .find_each do |teammate|
            dept = teammate.active_employment_tenure&.position&.title&.department
            if dept.nil?
              ids << teammate.id if include_none
            elsif selected_dept_ids.include?(dept.id)
              ids << teammate.id
            end
          end
        ids
      end

      def manager_teammate_ids_union
        effective_manager_ids
          .flat_map { |manager_id| teammate_ids_for_manager_filter(manager_id) }
          .to_set
      end

      def teammate_ids_for_manager_filter(manager_id)
        case manager_id
        when 'my_direct_employees'
          return [] unless current_company_teammate

          EmploymentTenure
            .where(company: company, manager_teammate: current_company_teammate, ended_at: nil)
            .pluck(:teammate_id)
        when 'my_employees_full_hierarchy'
          return [] unless current_company_teammate

          CompanyTeammate.self_and_reporting_hierarchy(current_company_teammate, company).pluck(:id)
        when 'just_me'
          current_company_teammate ? [current_company_teammate.id] : []
        when /\ACompanyTeammate_(\d+)\z/
          manager_teammate_id = Regexp.last_match(1).to_i
          EmploymentTenure
            .where(company: company, manager_teammate_id: manager_teammate_id, ended_at: nil)
            .pluck(:teammate_id)
        else
          []
        end
      end
    end
  end
end
