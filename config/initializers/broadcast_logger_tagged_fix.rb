# Fixes ActiveSupport::BroadcastLogger#tagged not yielding the block.
#
# BroadcastLogger has no #tagged method, so calls fall through to
# method_missing, which with 2+ sinks uses `loggers.map { |l| l.send(name, ...) }`.
# The `...` argument forwarding inside a map block does not properly forward
# the block argument, so each sink's #tagged sees block_given?==false and
# never yields — silently breaking ActiveJob::Logging's around_enqueue callback
# and preventing all jobs from being enqueued via perform_later.
ActiveSupport::BroadcastLogger.class_eval do
  def tagged(*tags, &block)
    if block
      begin
        @broadcasts.each { |logger| logger.push_tags(*tags) if logger.respond_to?(:push_tags) }
        block.call self
      ensure
        @broadcasts.each do |logger|
          next unless logger.respond_to?(:pop_tags)
          tags.size.times { logger.pop_tags rescue nil }
        end
      end
    else
      @broadcasts.map { |logger| logger.tagged(*tags) if logger.respond_to?(:tagged) }.compact.first
    end
  end
end
