# frozen_string_literal: true

module StartHere
  module Widget
    module Presets
      module_function

      # Ordered widget ids applied when a preset is chosen (must exist in Registry).
      def widget_ids_for(preset)
        case preset.to_sym
        when :manager
          # Manager default preset and blank Start Here dashboard (ensure_manager_default_if_blank!).
          %w[
            my_employees
            get_shit_done
            insights_goals_health
            about_me
            beta_check_in_history
            my_goals
            about_complete_picture
            beta_my_growth
            observations_involving_me
          ]
        when :non_manager
          # Matches start_here_dashboard_widgets_v1 non-manager layout (by position).
          %w[
            about_me
            get_shit_done
            my_goals
            kudos_wall
            observations_involving_me
            add_new_ogo
            beta_my_growth
            beta_check_in_history
            about_complete_picture
          ]
        when :og_enthusiast
          # Matches start_here_dashboard_widgets_v1 OG enthusiast layout (by position).
          %w[
            about_me
            add_new_ogo
            observations_involving_me
            kudos_wall
            all_observations
            insights_observations
            beta_check_in_history
            my_goals
            employee_hierarchy
            directory_teams
            my_employees
            abilities_index
            maap_assignments
            maap_positions
            admin_teams
            admin_aspirations
            celebrate_milestones
          ]
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
