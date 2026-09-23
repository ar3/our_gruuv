# frozen_string_literal: true

module Comments
  module CommentableBehaviors
    class TalentDensity < Base
      def allows_comments?
        commentable.open?
      end

      def allows_resolve?
        false
      end

      def slack_channel_notify?
        false
      end

      def destroy?(_comment, _viewing_teammate)
        false
      end

      def allows_comment_edits?
        commentable.open?
      end
    end
  end
end
