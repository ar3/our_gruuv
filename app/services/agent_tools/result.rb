# frozen_string_literal: true

module AgentTools
  # Tool return shape shared by in-app assistant and MCP adapters.
  # error_code is optional machine-readable (not_authorized, validation_failed, …).
  Result = Data.define(:ok?, :data, :error, :error_code) do
    def self.ok(data = {})
      new(true, data, nil, nil)
    end

    def self.err(error, code: nil)
      new(false, nil, error, code)
    end
  end
end
