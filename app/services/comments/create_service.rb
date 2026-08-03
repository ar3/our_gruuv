class Comments::CreateService
  def self.call(comment:, commentable:, organization:, creator:, position_suggestion: nil)
    new(
      comment: comment,
      commentable: commentable,
      organization: organization,
      creator: creator,
      position_suggestion: position_suggestion
    ).call
  end

  def initialize(comment:, commentable:, organization:, creator:, position_suggestion: nil)
    @comment = comment
    @commentable = commentable
    @organization = organization
    @creator = creator
    @position_suggestion = position_suggestion
    @behavior = Comments::CommentableBehavior.for(commentable)
  end

  def call
    return Result.err('Comments are not allowed on this item') unless @behavior.allows_comments?

    ApplicationRecord.transaction do
      @comment.commentable = @commentable
      @comment.organization = @organization
      @comment.creator = @creator
      @comment.position_suggestion = @position_suggestion if @position_suggestion

      if @comment.valid? && @comment.save
        @behavior.notify_after_create(@comment)
        Result.ok(@comment)
      else
        Result.err(@comment.errors.full_messages)
      end
    end
  rescue => e
    Rails.logger.error "Failed to create comment: #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")
    Result.err("Failed to create comment: #{e.message}")
  end
end
