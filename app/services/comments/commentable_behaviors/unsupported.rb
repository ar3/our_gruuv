# frozen_string_literal: true

module Comments
  module CommentableBehaviors
    class Unsupported < Base
      def supported?
        false
      end

      def allows_comments?
        false
      end

      def allows_resolve?
        false
      end
    end
  end
end
