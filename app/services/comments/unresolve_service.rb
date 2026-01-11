class Comments::UnresolveService
  def self.call(comment:)
    new(comment: comment).call
  end

  def initialize(comment:)
    @comment = comment
  end

  def call
    ApplicationRecord.transaction do
      @comment.unresolve!
      
      # Update Slack notification if this is a root comment
      if @comment.root_comment?
        Comments::PostNotificationJob.perform_and_get_result(@comment.id)
      end
      
      Result.ok(@comment)
    end
  rescue => e
    Rails.logger.error "Failed to unresolve comment: #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")
    Result.err("Failed to unresolve comment: #{e.message}")
  end
end
