# frozen_string_literal: true

module Debug
  # Service to gather authorization debug information for check-ins page
  # Evaluates PersonPolicy#view_check_ins? which delegates to audit?
  class CheckInsDebugService
    attr_reader :pundit_user, :person

    def initialize(pundit_user:, person:)
      @pundit_user = pundit_user
      @person = person
    end

    def call
      policy = PersonPolicy.new(pundit_user, person)
      
      {
        policy: policy,
        policy_class: 'PersonPolicy',
        policy_record: person,
        policy_action: 'view_check_ins?',
        conditions: evaluate_conditions(policy),
        final_result: policy.view_check_ins?
      }
    end

    private

    def evaluate_conditions(policy)
      viewing_teammate = policy.send(:viewing_teammate)
      record = policy.record
      own_profile_result = viewing_teammate && viewing_teammate.person == record
      
      {
        admin_bypass: {
          result: policy.send(:admin_bypass?),
          description: 'admin_bypass?',
          details: viewing_teammate ? "og_admin? = #{viewing_teammate.person&.og_admin?}" : 'No viewing_teammate'
        },
        viewing_teammate_and_record: {
          result: viewing_teammate.present? && record.present?,
          description: 'viewing_teammate && record',
          details: "viewing_teammate: #{viewing_teammate.present?}, record: #{record.present?}"
        },
        not_terminated: {
          result: viewing_teammate ? !viewing_teammate.terminated? : nil,
          description: '!viewing_teammate.terminated?',
          details: viewing_teammate ? (viewing_teammate.terminated? ? 'Teammate is terminated' : 'Not terminated') : 'No viewing_teammate'
        },
        own_profile: {
          result: own_profile_result,
          description: 'viewing_teammate.person == record',
          details: own_profile_result ? 'Viewing own profile' : 'Not own profile'
        },
        has_active_employment_tenure: {
          result: viewing_teammate && !own_profile_result ? viewing_teammate.has_active_employment_tenure? : nil,
          description: 'viewing_teammate.has_active_employment_tenure?',
          details: viewing_teammate && !own_profile_result ? (viewing_teammate.has_active_employment_tenure? ? 'Has active tenure' : 'No active employment tenure') : 'N/A (own profile or no viewing_teammate)'
        },
        can_manage_employment: {
          result: viewing_teammate && !own_profile_result ? viewing_teammate.can_manage_employment? : nil,
          description: 'viewing_teammate.can_manage_employment?',
          details: viewing_teammate && !own_profile_result ? (viewing_teammate.can_manage_employment? ? 'Can manage employment' : 'Cannot manage employment') : 'N/A (own profile or no viewing_teammate)'
        },
        in_managerial_hierarchy: {
          result: viewing_teammate && !own_profile_result ? viewing_teammate.person.in_managerial_hierarchy_of?(record, viewing_teammate.organization) : nil,
          description: 'viewing_teammate.person.in_managerial_hierarchy_of?(record, organization)',
          details: viewing_teammate && !own_profile_result ? (viewing_teammate.person.in_managerial_hierarchy_of?(record, viewing_teammate.organization) ? 'In managerial hierarchy' : 'Not in managerial hierarchy') : 'N/A (own profile or no viewing_teammate)'
        }
      }
    end
  end
end

