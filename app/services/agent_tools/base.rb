# frozen_string_literal: true

module AgentTools
  class Base
    def self.call(context:, **args)
      new.call(context: context, **args)
    end

    def call(context:, **args)
      raise NotImplementedError, "#{self.class.name}#call must be implemented"
    end

    private

    def ok(data = {})
      AgentTools::Result.ok(data)
    end

    def err(message)
      AgentTools::Result.err(message)
    end
  end
end
