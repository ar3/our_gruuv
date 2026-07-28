# frozen_string_literal: true

module AgentTools
  class Error < StandardError; end
  class NotAuthorized < Error; end
  class UnknownTool < Error; end
  class InvalidArguments < Error; end
end
