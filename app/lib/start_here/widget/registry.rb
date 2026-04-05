# frozen_string_literal: true

module StartHere
  module Widget
    module Registry
      module_function

      def widget_ids
        @widget_ids ||= Dir[Rails.root.join("app/lib/start_here/widgets/*_widget.rb")].map do |path|
          File.basename(path, ".rb").delete_suffix("_widget")
        end.sort.freeze
      end

      def klass_for(widget_id)
        camel = widget_id.to_s.camelize
        "StartHere::Widgets::#{camel}Widget".constantize
      end

      def instance(widget_id, context)
        klass_for(widget_id).new(context)
      end
    end
  end
end
