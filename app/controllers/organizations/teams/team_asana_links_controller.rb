# frozen_string_literal: true

module Organizations
  module Teams
    class TeamAsanaLinksController < Organizations::OrganizationNamespaceBaseController
      before_action :authenticate_person!
      before_action :set_team
      before_action :set_team_asana_link

      def show
        authorize @team_asana_link, :update?
        @source = @team_asana_link&.external_project_source

        if @source == 'asana' && current_company_teammate&.has_asana_identity? && @team_asana_link&.asana_project_id
          @has_project_access = check_asana_project_access(@team_asana_link.asana_project_id)
        else
          @has_project_access = nil
        end
      end

      def create
        authorize @team_asana_link, :update?

        url = team_asana_link_params[:url]
        if url.present?
          source = ExternalProjectUrlParser.detect_source(url)
          if source == 'asana'
            project_id = extract_asana_project_id(url)
            if project_id
              @team_asana_link.deep_integration_config ||= {}
              @team_asana_link.deep_integration_config['asana_project_id'] = project_id
            end
          end
        end

        @team_asana_link.assign_attributes(team_asana_link_params)
        if @team_asana_link.save
          redirect_to organization_team_team_asana_link_path(organization, @team), notice: 'Team Asana link created successfully.'
        else
          render :show, status: :unprocessable_entity
        end
      end

      def update
        authorize @team_asana_link

        url = team_asana_link_params[:url]
        if url.present?
          source = ExternalProjectUrlParser.detect_source(url)
          if source == 'asana'
            project_id = extract_asana_project_id(url)
            if project_id
              @team_asana_link.deep_integration_config ||= {}
              @team_asana_link.deep_integration_config['asana_project_id'] = project_id
            end
          end
        end

        @team_asana_link.assign_attributes(team_asana_link_params)
        if @team_asana_link.save
          redirect_to organization_team_team_asana_link_path(organization, @team), notice: 'Team Asana link updated successfully.'
        else
          render :show, status: :unprocessable_entity
        end
      end

      def sync
        authorize @team_asana_link, :update?

        source = params[:source] || @team_asana_link.external_project_source
        unless source.present?
          redirect_to organization_team_team_asana_link_path(organization, @team), alert: 'No project source detected.'
          return
        end

        result = ExternalProjectCacheService.sync_project(@team_asana_link, source, current_company_teammate)

        if result[:success]
          redirect_to organization_team_team_asana_link_path(organization, @team), notice: 'Project synced successfully.'
        else
          flash[:sync_error_type] = result[:error_type]
          redirect_to organization_team_team_asana_link_path(organization, @team),
                      alert: format_sync_error_message(result, source)
        end
      end

      def associate_project
        authorize @team_asana_link, :update?
        redirect_to organization_team_team_asana_link_path(organization, @team), notice: 'Project association not yet implemented.'
      end

      def disassociate_project
        authorize @team_asana_link, :update?

        source = params[:source] || @team_asana_link.external_project_source
        unless source.present?
          redirect_to organization_team_team_asana_link_path(organization, @team), alert: 'No project source detected.'
          return
        end

        cache = @team_asana_link.external_project_cache_for(source)
        if cache
          cache.destroy
          redirect_to organization_team_team_asana_link_path(organization, @team), notice: 'Project cache removed successfully.'
        else
          redirect_to organization_team_team_asana_link_path(organization, @team), alert: 'No cache found to remove.'
        end
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
        @team_asana_link = @team&.team_asana_link || TeamAsanaLink.new(team: @team)
      end

      def extract_asana_project_id(url)
        AsanaUrlParser.extract_project_id(url)
      end

      def team_asana_link_params
        params.require(:team_asana_link).permit(:url)
      end

      def format_sync_error_message(result, source)
        error_type = result[:error_type] || 'unknown_error'
        base_message = result[:error] || 'Unknown error occurred'

        case error_type
        when 'token_expired'
          source_name = source == 'asana' ? 'Asana' : source.titleize
          "Your #{source_name} token has expired. Please reconnect your account to sync the project."
        when 'permission_denied'
          "You do not have permission to access this project. #{base_message}"
        when 'not_found', 'project_not_found'
          'Project not found. Please verify the project URL is correct.'
        when 'not_authenticated'
          source_name = source == 'asana' ? 'Asana' : source.titleize
          "You are not authenticated with #{source_name}. Please connect your account first."
        when 'network_error'
          "Network error: #{base_message}. Please try again later."
        when 'api_error'
          "API error: #{base_message}. Please try again later."
        else
          "Failed to sync project: #{base_message}"
        end
      end

      def check_asana_project_access(project_id)
        return false unless current_company_teammate&.has_asana_identity?

        service = AsanaService.new(current_company_teammate)
        return false unless service.authenticated?

        sections_result = service.fetch_project_sections(project_id)
        sections_result[:success]
      end
    end
  end
end
