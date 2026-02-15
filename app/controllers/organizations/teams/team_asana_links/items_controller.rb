# frozen_string_literal: true

module Organizations
  module Teams
    module TeamAsanaLinks
      class ItemsController < Organizations::OrganizationNamespaceBaseController
        before_action :authenticate_person!
        before_action :set_team
        before_action :set_team_asana_link
        before_action :set_item

        def show
          authorize @team_asana_link
          @source = params[:source] || @team_asana_link.external_project_source

          unless @source.present?
            redirect_to organization_team_team_asana_link_path(organization, @team), alert: 'No project source detected.'
            return
          end

          item_result = fetch_item_details(@item_gid, @source)

          unless item_result && item_result[:success]
            error_msg = item_result&.dig(:message) || item_result&.dig(:error) || 'Item not found or could not be fetched.'
            redirect_to organization_team_team_asana_link_path(organization, @team), alert: error_msg
            return
          end

          @item_details = item_result[:task]
          render layout: 'overlay'
        end

        private

        def set_team
          id_from_params = params[:team_id].to_s.split('-').first.to_i
          return if id_from_params.zero?

          @team = Team.for_company(organization).active.find(id_from_params)
        rescue ActiveRecord::RecordNotFound
          redirect_to organization_teams_path(organization), alert: 'Team not found.'
        end

        def set_team_asana_link
          @team_asana_link = @team&.team_asana_link
          unless @team_asana_link&.url.present?
            redirect_to organization_team_path(organization, @team), alert: 'Team Asana link not configured.'
          end
        end

        def set_item
          @item_gid = params[:id] || params[:item_gid]
          unless @item_gid.present?
            redirect_to organization_team_team_asana_link_path(organization, @team), alert: 'Item ID required.'
          end
        end

        def fetch_item_details(item_gid, source)
          case source
          when 'asana'
            service = AsanaService.new(current_company_teammate)
            if service.authenticated?
              task = service.fetch_task_details(item_gid)
              task ? { success: true, task: task } : { success: false, error: 'Task not found' }
            else
              { success: false, error: 'Not authenticated with Asana' }
            end
          else
            { success: false, error: 'Unknown source' }
          end
        end
      end
    end
  end
end
