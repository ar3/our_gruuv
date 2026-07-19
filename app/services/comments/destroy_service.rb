# frozen_string_literal: true

class Comments::DestroyService
  def self.call(comment:)
    new(comment: comment).call
  end

  def initialize(comment:)
    @comment = comment
  end

  def call
    ApplicationRecord.transaction do
      @comment.destroy!
      Result.ok(@comment)
    end
  rescue => e
    Rails.logger.error "Failed to destroy comment: #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")
    Result.err("Failed to destroy comment: #{e.message}")
  end
end
