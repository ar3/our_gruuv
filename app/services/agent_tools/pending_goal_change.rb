# frozen_string_literal: true

module AgentTools
  # Short-lived MCP mutation proposals (preview → confirm). Uses Rails.cache
  # (Solid Cache in production). Specs should use MemoryStore — test env null_store
  # will not round-trip tokens.
  class PendingGoalChange
    TTL = 30.minutes
    ACTIONS = %w[update_goal set_confidence advance_progressive_aim].freeze

    def self.store(context:, action:, payload:, preview:)
      action_name = action.to_s
      raise ArgumentError, "Unknown pending action: #{action_name}" unless ACTIONS.include?(action_name)

      token = SecureRandom.uuid
      Rails.cache.write(
        cache_key(context, token),
        {
          "action" => action_name,
          "payload" => deep_stringify(payload),
          "preview" => deep_stringify(preview),
          "person_id" => context.person.id,
          "organization_id" => context.organization.id,
          "company_teammate_id" => context.company_teammate&.id
        },
        expires_in: TTL
      )
      token
    end

    def self.consume(context:, token:)
      return nil if token.blank?

      key = cache_key(context, token)
      data = Rails.cache.read(key)
      return nil if data.blank?
      return nil unless data["person_id"] == context.person.id
      return nil unless data["organization_id"] == context.organization.id

      Rails.cache.delete(key)
      data
    end

    def self.cache_key(context, token)
      "agent_tools:pending_goal_change:#{context.organization.id}:#{context.person.id}:#{token}"
    end
    private_class_method :cache_key

    def self.deep_stringify(value)
      case value
      when Hash
        value.to_h.transform_keys(&:to_s).transform_values { |v| deep_stringify(v) }
      when Array
        value.map { |v| deep_stringify(v) }
      else
        value
      end
    end
    private_class_method :deep_stringify
  end
end
