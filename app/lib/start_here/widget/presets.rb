# frozen_string_literal: true

module StartHere
  module Widget
    module Presets
      module_function

      # Ordered widget ids applied when a preset is chosen (must exist in Registry).
      def widget_ids_for(preset)
        case preset.to_sym
        when :manager
          # Matches typical start_here_dashboard_widgets_v1 manager layout (by position).
          %w[
            about_me
            get_shit_done
            my_goals
            my_employees
            kudos_wall
            insights_dashboard
            observations_involving_me
            beta_my_growth
            beta_check_in_history
            about_complete_picture
          ]
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
