module AsanaErrors
  class AsanaError < StandardError
    attr_reader :error_type, :original_message

    def initialize(message, error_type: 'asana_error', original_message: nil)
      super(message)
      @error_type = error_type
      @original_message = original_message
    end
  end

  class TokenExpiredError < AsanaError
    def initialize(message = 'Asana token expired. Please reconnect your account.', original_message: nil)
      super(message, error_type: 'token_expired', original_message: original_message)
    end
  end

  class PermissionDeniedError < AsanaError
    def initialize(message = 'You do not have permission to access this resource.', original_message: nil)
      super(message, error_type: 'permission_denied', original_message: original_message)
    end
  end

  class ProjectNotFoundError < AsanaError
    def initialize(message = 'Project not found in Asana.', original_message: nil)
      super(message, error_type: 'project_not_found', original_message: original_message)
    end
  end

  class NetworkError < AsanaError
    def initialize(message = 'Failed to connect to Asana.', original_message: nil)
      super(message, error_type: 'network_error', original_message: original_message)
    end
  end

  class NotAuthenticatedError < AsanaError
    def initialize(message = 'Not authenticated with Asana.', original_message: nil)
      super(message, error_type: 'not_authenticated', original_message: original_message)
    end
  end
end

