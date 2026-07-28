# frozen_string_literal: true

module AgentTools
  # Tool return shape shared by in-app assistant and (later) MCP adapters.
  Result = Data.define(:ok?, :data, :error) do
    def self.ok(data = {})
      new(true, data, nil)
    end

    def self.err(error)
      new(false, nil, error)
    end
  end
end
