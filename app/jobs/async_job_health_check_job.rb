class AsyncJobHealthCheckJob < ApplicationJob
  queue_as :default

  def perform(enqueued_at_ms)
    duration_ms = ((Time.now.to_f * 1000) - enqueued_at_ms).round
    Rails.logger.info "[AsyncJobHealthCheck] Job performed! Latency: #{duration_ms}ms"

    Rails.cache.write(
      "async_job_health_check_last_performed",
      { performed_at: Time.current.iso8601, latency_ms: duration_ms, pid: Process.pid },
      expires_in: 10.minutes
    )
  end
end
