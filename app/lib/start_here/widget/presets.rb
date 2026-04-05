# frozen_string_literal: true

module StartHere
  module Widget
    module Presets
      module_function

      # Ordered widget ids applied when a preset is chosen (must exist in Registry).
      def widget_ids_for(preset)
        case preset.to_sym
        when :manager
          %w[about_me get_shit_done kudos_wall my_employees insights_dashboard]
        when :non_manager
          %w[about_me get_shit_done kudos_wall my_goals insights_dashboard]
        when :og_enthusiast
          %w[about_me add_new_ogo observations_involving_me kudos_wall all_observations insights_observations]
        else
          []
        end
      end

      def valid?(preset)
        widget_ids_for(preset).present?
      end
    end
  end
end
