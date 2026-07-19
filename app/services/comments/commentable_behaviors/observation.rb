# frozen_string_literal: true

module Comments
  module CommentableBehaviors
    class Observation < Base
      def allows_comments?
        commentable.published? && !commentable.soft_deleted?
      end

      def allows_resolve?
        false
      end

      def slack_channel_notify?
        false
      end

      # Creator or employment manager (`can_manage_employment`) may delete.
      # Notify is SI-only (pull); nothing to enqueue on create/update.
      def destroy?(comment, viewing_teammate)
        return false unless viewing_teammate
        return false unless viewing_teammate.organization_id == comment.organization_id

        person = viewing_teammate.person
        return true if comment.creator_id == person.id
        return true if viewing_teammate.can_manage_employment?

        false
      end
    end
  end
end
