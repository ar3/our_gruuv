class Comments::UpdateService
  def self.call(comment:, params:)
    new(comment: comment, params: params).call
  end

  def initialize(comment:, params:)
    @comment = comment
    @params = params
    @behavior = Comments::CommentableBehavior.for(comment)
    @resolved_at_changed = false
  end

  def call
    ApplicationRecord.transaction do
      old_resolved_at = @comment.resolved_at
      old_body = @comment.body

      @comment.assign_attributes(@params)
      @resolved_at_changed = old_resolved_at != @comment.resolved_at
      @body_changed = old_body != @comment.body

      if @comment.save
        if @resolved_at_changed || @body_changed
          @behavior.notify_after_update(@comment)
        end

        Result.ok(@comment)
      else
        Result.err(@comment.errors.full_messages)
      end
    end
  rescue => e
    Rails.logger.error "Failed to update comment: #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")
    Result.err("Failed to update comment: #{e.message}")
  end
end
