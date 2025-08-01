Sentry.init do |config|
  config.dsn = ENV['SENTRY_DSN'] || 'https://26aee5ad1168a832412c32f9c3d646a1@o83164.ingest.us.sentry.io/4509712954884096'
  
  # Only send errors in production and staging
#   config.enabled_environments = %w[production staging]
  
  # Set the environment
  config.environment = Rails.env
  
  # Set the release version (useful for tracking which version caused an error)
  config.release = ENV['RAILWAY_GIT_COMMIT_SHA'] || 'development'
  
  # Configure breadcrumbs (automatic logging of user actions)
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]
  config.send_default_pii = true
  
  # Configure sampling (only send a percentage of errors in high-traffic environments)
  config.traces_sample_rate = 0.1
  
  # Configure error sampling
  config.sample_rate = 1.0
  
  # Add user context when available
  config.before_send = lambda do |event, hint|
    # Add user context if we have a current person
    if defined?(current_person) && current_person
      event.set_user(
        id: current_person.id,
        email: current_person.email,
        name: current_person.display_name
      )
    end
    
    # Add request context
    if defined?(request) && request
      event.set_context('request', {
        url: request.url,
        method: request.method,
        user_agent: request.user_agent,
        ip: request.remote_ip
      })
    end
    
    event
  end
  
  # Configure which exceptions to ignore
#   config.excluded_exceptions += [
#     'ActionController::RoutingError',
#     'ActionController::UnknownFormat',
#     'ActionController::BadRequest',
#     'ActionController::ParameterMissing'
#   ]
  
  # Configure performance monitoring
  config.enable_tracing = true
  
  # Configure the logger to capture Rails.logger.error messages
  config.sdk_logger = Rails.logger
end

# Create a custom logger that sends error messages to Sentry
class SentryLogger < ActiveSupport::Logger::SimpleFormatter
  def call(severity, timestamp, progname, msg)
    if severity == 'ERROR'
      Sentry.capture_message(msg, level: :error)
    end
    super
  end
  
  # Add missing methods that Rails expects
  def push_tags(*tags)
    # No-op for SentryLogger, but return an array for Rails compatibility
    []
  end
  
  def pop_tags
    # No-op for SentryLogger, but return an array for Rails compatibility
    []
  end
  
  def clear_tags!
    # No-op for SentryLogger
  end
  
  def current_tags
    []
  end
  
  def tagged(*tags)
    # No-op for SentryLogger, but return self for Rails compatibility
    self
  end
end

# Configure Rails logger to use our custom formatter
Rails.logger.formatter = SentryLogger.new 