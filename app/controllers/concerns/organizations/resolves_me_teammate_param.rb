# frozen_string_literal: true

module Organizations
  # Lets teammate-scoped URLs use "me" (or legacy "my") instead of a numeric id so links
  # are portable when the signed-in viewer is the subject teammate.
  module ResolvesMeTeammateParam
    extend ActiveSupport::Concern

    ME_TEAMMATE_ALIASES = %w[me my].freeze

    protected

    # Returns an id (or other value) suitable for +relation.find(resolved)+.
    # "me" / "my" (case-insensitive) resolve to +current_company_teammate.id+.
    def resolve_teammate_route_id(raw)
      return raw if raw.nil?

      str = raw.to_s.strip
      return raw if str.blank?

      if ME_TEAMMATE_ALIASES.include?(str.downcase)
        raise ActiveRecord::RecordNotFound, "Unknown teammate" if current_company_teammate.blank?

        return current_company_teammate.id
      end

      raw
    end

    def find_organization_teammate!(raw_id, scope: organization.teammates)
      scope.find(resolve_teammate_route_id(raw_id))
    end
  end
end
