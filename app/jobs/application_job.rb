class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError
  
  # Add error tracking for job failures
  rescue_from StandardError do |exception|
    Sentry.capture_exception(exception) do |event|
      event.set_context('job', {
        class: self.class.name,
        job_id: job_id,
        arguments: arguments
      })
    end
    
    # Re-raise the exception to maintain job retry behavior
    raise exception
  end
end
