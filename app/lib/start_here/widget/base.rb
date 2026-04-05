# frozen_string_literal: true

module StartHere
  module Widget
    class Base
      class << self
        def widget_hash
          const_get(:START_HERE_WIDGET)
        end

        def widget_id
          widget_hash[:id].to_s
        end
      end

      attr_reader :context

      def initialize(context)
        @context = context
      end

      def view
        context.view
      end

      def widget_hash
        self.class.widget_hash
      end

      def selection_group
        widget_hash[:group]
      end

      def selection_title
        widget_hash[:selection_title]
      end

      def selection_description
        widget_hash[:selection_description]
      end

      def icon
        widget_hash[:icon]
      end

      def widget_id
        widget_hash[:id].to_s
      end

      def display_title
        evaluate_field(widget_hash[:label])
      end

      def button_label
        evaluate_field(widget_hash[:button_label])
      end

      def button_path
        evaluate_field(widget_hash[:path])
      end

      def dashboard_content
        d = widget_hash[:description]
        text =
          case d
          when :start_here_dynamic_gsd
            dynamic_get_shit_done_summary
          when Proc
            d.call(context)
          when String
            d
          when nil
            nil
          else
            d.to_s
          end

        return ActiveSupport::SafeBuffer.new if text.blank?

        view.tag.p(class: "text-muted small mb-0") { text }
      end

      def active?
        button_path.present?
      rescue StandardError
        false
      end

      private

      def evaluate_field(value)
        case value
        when Proc
          value.call(context)
        else
          value
        end
      end

      def dynamic_get_shit_done_summary
        pending = view.pending_get_shit_done_count(context.company_teammate)
        if pending.zero?
          "Nothing needs your attention right now."
        elsif pending == 1
          "1 item needs your attention."
        else
          "#{pending} items need your attention."
        end
      end
    end
  end
end
