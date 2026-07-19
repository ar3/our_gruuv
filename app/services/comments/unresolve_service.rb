class Comments::UnresolveService
  def self.call(comment:)
    new(comment: comment).call
  end

  def initialize(comment:)
    @comment = comment
    @behavior = Comments::CommentableBehavior.for(comment)
  end

  def call
    return Result.err('Unresolve is not available for this comment') unless @behavior.allows_resolve?

    ApplicationRecord.transaction do
      @comment.unresolve!

      if @comment.root_comment?
        @behavior.notify_after_update(@comment)
      end

      Result.ok(@comment)
    end
  rescue => e
    Rails.logger.error "Failed to unresolve comment: #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")
    Result.err("Failed to unresolve comment: #{e.message}")
  end
end
