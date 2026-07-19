# frozen_string_literal: true

module Comments
  module CommentableBehaviors
    class Base
      attr_reader :commentable

      def initialize(commentable)
        @commentable = commentable
      end

      def supported?
        true
      end

      def allows_comments?
        raise NotImplementedError
      end

      def allows_resolve?
        raise NotImplementedError
      end

      def slack_channel_notify?
        false
      end

      def destroy?(comment, viewing_teammate)
        false
      end

      def notify_after_create(comment)
        # no-op by default
      end

      def notify_after_update(comment)
        # no-op by default
      end
    end
  end
end
