# frozen_string_literal: true

# Factory for per-root-commentable behavior (notify, resolve, delete, commentability).
# Nested Comment records inherit the root commentable's strategy.
class Comments::CommentableBehavior
  MAAP_TYPES = [Assignment, Ability, Aspiration, Position, Title].freeze

  def self.for(commentable)
    root = root_commentable_for(commentable)
    case root
    when ::Observation
      Comments::CommentableBehaviors::Observation.new(root)
    when *MAAP_TYPES
      Comments::CommentableBehaviors::Maap.new(root)
    else
      Comments::CommentableBehaviors::Unsupported.new(root)
    end
  end

  def self.root_commentable_for(commentable)
    return nil if commentable.nil?
    return commentable.root_commentable if commentable.is_a?(Comment)

    commentable
  end
end
