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
  
  # Configure error sampling - capture 100% of exceptions
  config.sample_rate = 1.0
  
  # Configure stack trace filtering to hide exception handlers
  # This ensures the original exception location is highlighted, not the handler
  config.backtrace_cleanup_callback = lambda do |backtrace|
    # Filter out exception handling methods from stack traces
    # Backtrace lines are strings like: "/path/to/file.rb:123:in 'method_name'"
    backtrace.reject do |line|
      line.match?(/handle_unexpected_error|handle_standard_error|capture_error_in_sentry|rescue_from|ApplicationController.*handle_|ApplicationJob.*rescue/)
    end
  end
  
  # Add user context when available (safe for all contexts)
  config.before_send = lambda do |event, hint|
    begin
      # Add user context if we have a current person (only in controller context)
      if defined?(current_person) && respond_to?(:current_person) && current_person
        event.set_user(
          id: current_person.id,
          email: current_person.email,
          name: current_person.display_name
        )
      end
    rescue => e
      # Don't let context setting break error reporting
      Rails.logger.warn "Sentry before_send: Failed to set user context: #{e.message}"
    end
    
    begin
      # Add request context (only in controller context)
      if defined?(request) && respond_to?(:request) && request
        event.set_context('request', {
          url: request.url,
          method: request.method,
          user_agent: request.user_agent,
          ip: request.remote_ip
        })
      end
    rescue => e
      # Don't let context setting break error reporting
      Rails.logger.warn "Sentry before_send: Failed to set request context: #{e.message}"
    end
    
    event
  end
  
  # Configure which exceptions to ignore
  config.excluded_exceptions += [
    'ActionController::RoutingError'
  ]
  
  # Configure performance monitoring
  # Note: enable_tracing is deprecated, using traces_sample_rate instead (set above)
  
  # Configure the logger to capture Rails.logger.error messages
  config.sdk_logger = Rails.logger
end

# Create a custom logger that sends error messages to Sentry
# Note: This captures ERROR level log messages (not exceptions).
# Exceptions are captured separately via capture_exception calls.
# This ensures we capture both structured exceptions and error messages.
class SentryLogger < ActiveSupport::Logger::SimpleFormatter
  def call(severity, timestamp, progname, msg)
    if severity == 'ERROR'
      # Only capture messages, not exception backtraces (those are captured as exceptions)
      # Skip very long messages that are likely backtraces
      unless msg.to_s.length > 1000 || msg.to_s.include?('backtrace') || msg.to_s.match?(/^\s+from\s/)
        Sentry.capture_message(msg, level: :error)
      end
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