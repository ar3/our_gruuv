# frozen_string_literal: true

module AgentTools
  # Controls how much MAAP body text is included in tool payloads.
  # Default is expensive (full fields); minimal is identity-only for lower token use.
  module Detail
    VALUES = %w[expensive minimal].freeze
    DEFAULT = "expensive"

    module_function

    def normalize(value)
      detail = value.to_s.strip.presence || DEFAULT
      return detail if VALUES.include?(detail)

      raise ArgumentError, "detail must be one of: #{VALUES.join(', ')}"
    end

    def expensive?(value)
      normalize(value) == "expensive"
    end
  end
end
