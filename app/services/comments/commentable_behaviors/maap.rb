# frozen_string_literal: true

module Comments
  module CommentableBehaviors
    class Maap < Base
      def allows_comments?
        true
      end

      def allows_resolve?
        true
      end

      def slack_channel_notify?
        true
      end

      # MAAP comments have historically had no destroy action; keep that.
      def destroy?(_comment, _viewing_teammate)
        false
      end

      def notify_after_create(comment)
        enqueue_slack(comment)
      end

      def notify_after_update(comment)
        return unless comment.root_comment?

        Comments::PostNotificationJob.perform_and_get_result(comment.id)
      end

      private

      def enqueue_slack(comment)
        if comment.root_comment?
          Comments::PostNotificationJob.perform_and_get_result(comment.id)
        else
          root_comment = find_root_comment(comment)
          Comments::PostNotificationJob.perform_and_get_result(root_comment.id) if root_comment
        end
      end

      def find_root_comment(comment)
        current = comment
        while current.commentable.is_a?(Comment)
          current = current.commentable
        end
        current
      end
    end
  end
end
