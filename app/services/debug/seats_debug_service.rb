# frozen_string_literal: true

module Debug
  # Service to gather authorization debug information for seats page
  # Evaluates SeatPolicy#create? which controls seat creation and bulk actions
  class SeatsDebugService
    attr_reader :pundit_user, :organization

    def initialize(pundit_user:, organization:)
      @pundit_user = pundit_user
      @organization = organization
    end

    def call
      # Create a new Seat instance for policy evaluation (same as controller does)
      seat_record = Seat.new
      policy = SeatPolicy.new(pundit_user, seat_record)
      
      {
        policy: policy,
        policy_class: 'SeatPolicy',
        policy_record: seat_record,
        policy_action: 'create?',
        conditions: evaluate_conditions(policy),
        final_result: policy.create?
      }
    end

    private

    def evaluate_conditions(policy)
      viewing_teammate = policy.send(:viewing_teammate)
      actual_org = policy.send(:actual_organization)
      person = viewing_teammate&.person
      
      # Determine actual_organization source for debugging
      org_source = if policy.record.is_a?(Organization)
        'record (Organization)'
      elsif policy.record.respond_to?(:organization) && policy.record.organization
        'record.organization'
      else
        'viewing_teammate.organization (fallback)'
      end
      
      {
        admin_bypass: {
          result: policy.send(:admin_bypass?),
          description: 'admin_bypass?',
          details: viewing_teammate ? "og_admin? = #{viewing_teammate.person&.og_admin?}" : 'No viewing_teammate'
        },
        viewing_teammate_present: {
          result: viewing_teammate.present?,
          description: 'viewing_teammate present',
          details: viewing_teammate ? "Teammate ID: #{viewing_teammate.id}" : 'No viewing_teammate'
        },
        actual_organization_present: {
          result: actual_org.present?,
          description: 'actual_organization present',
          details: actual_org ? "Organization: #{actual_org.name} (ID: #{actual_org.id}) - Source: #{org_source}" : 'No organization found'
        },
        organization_matches: {
          result: actual_org == organization,
          description: 'actual_organization matches route organization',
          details: actual_org == organization ? "Matches route organization (#{organization.name})" : "Mismatch: actual_org=#{actual_org&.name}, route_org=#{organization.name}"
        },
        can_manage_maap: {
          result: person && actual_org ? person.can_manage_maap?(actual_org) : nil,
          description: 'person.can_manage_maap?(organization)',
          details: if person && actual_org
            can_manage = person.can_manage_maap?(actual_org)
            can_manage ? "Can manage MAAP for #{actual_org.name}" : "Cannot manage MAAP for #{actual_org.name}"
          else
            'N/A (no person or organization)'
          end
        }
      }
    end
  end
end

