class Comments::CreateService
  def self.call(comment:, commentable:, organization:, creator:)
    new(comment: comment, commentable: commentable, organization: organization, creator: creator).call
  end

  def initialize(comment:, commentable:, organization:, creator:)
    @comment = comment
    @commentable = commentable
    @organization = organization
    @creator = creator
  end

  def call
    ApplicationRecord.transaction do
      # Set attributes (form may have already set some via sync, but we ensure they're correct)
      @comment.commentable = @commentable
      @comment.organization = @organization
      @comment.creator = @creator
      
      # Validate and save
      if @comment.valid? && @comment.save
        # Notify Slack for root comments
        if @comment.root_comment?
          Comments::PostNotificationJob.perform_and_get_result(@comment.id)
        else
          # For nested comments, update the root comment's Slack message
          root_comment = find_root_comment
          Comments::PostNotificationJob.perform_and_get_result(root_comment.id) if root_comment
        end
        
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

  private

  def find_root_comment
    current = @comment
    while current.commentable.is_a?(Comment)
      current = current.commentable
    end
    current
  end
end
