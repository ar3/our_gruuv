class Comment < ApplicationRecord
  # Associations
  belongs_to :commentable, polymorphic: true
  belongs_to :organization
  belongs_to :creator, class_name: 'Person'

  # Self-referential association for nested comments
  has_many :comments, as: :commentable, dependent: :destroy

  # Validations
  validates :body, presence: true
  validates :organization, presence: true
  validates :creator, presence: true
  validates :commentable, presence: true

  # Associations
  has_many :notifications, as: :notifiable, dependent: :destroy

  # Scopes
  scope :unresolved, -> { where(resolved_at: nil) }
  scope :resolved, -> { where.not(resolved_at: nil) }
  scope :for_commentable, ->(commentable) { where(commentable_type: commentable.class.name, commentable_id: commentable.id) }
  scope :root_comments, -> { where.not(commentable_type: 'Comment') }
  scope :ordered, -> { order(created_at: :asc) }

  # Instance methods
  def resolved?
    resolved_at.present?
  end

  def resolve!
    transaction do
      update!(resolved_at: Time.current)
      descendants.update_all(resolved_at: Time.current)
    end
  end

  def unresolve!
    update!(resolved_at: nil)
    # Descendants remain resolved (independent behavior)
  end

  def descendants
    # Recursively find all nested comments using a more efficient approach
    all_descendant_ids = []
    current_level_ids = [id]
    
    while current_level_ids.any?
      # Find direct children of current level
      child_ids = Comment.where(commentable_type: 'Comment', commentable_id: current_level_ids)
                         .pluck(:id)
      
      all_descendant_ids.concat(child_ids)
      current_level_ids = child_ids
    end
    
    Comment.where(id: all_descendant_ids)
  end

  def root_commentable
    # Traverse up the commentable chain to find the original commentable
    current = commentable
    while current.is_a?(Comment)
      current = current.commentable
    end
    current
  end

  def root_comment?
    !commentable.is_a?(Comment)
  end

  def slack_url
    return nil unless slack_message_id.present?
    
    company = organization.root_company || organization
    return nil unless company.company?
    return nil unless company.maap_object_comment_channel_id.present?
    
    channel = company.maap_object_comment_channel
    channel_name = channel.display_name.gsub('#', '')
    
    slack_config = company.calculated_slack_config
    return nil unless slack_config&.workspace_url.present?
    
    "#{slack_config.workspace_url}/archives/#{channel_name}/p#{slack_message_id.gsub('.', '')}"
  end
end
