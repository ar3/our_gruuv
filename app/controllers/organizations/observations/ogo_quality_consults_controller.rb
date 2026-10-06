# frozen_string_literal: true

module Organizations
  module Observations
    class OgoQualityConsultsController < OrganizationNamespaceBaseController
      before_action :set_observation, except: [:create]

      def create
        existing = observation_from_id
        if existing
          authorize existing, :consult_ogo_quality?
        else
          authorize Observation, :create?
        end

        result = ::Observations::StartOgoQualityConsult.call(
          organization: organization,
          current_person: current_person,
          triggered_by_teammate: current_company_teammate,
          observation: existing,
          story: observation_params[:story],
          observee_ids: Array(params[:observee_ids]),
          observation_type: observation_params[:observation_type],
          privacy_level: observation_params[:privacy_level],
          primary_feeling: observation_params[:primary_feeling],
          secondary_feeling: observation_params[:secondary_feeling]
        )

        if result.ok?
          authorize result.observation, :consult_ogo_quality?
          redirect_to typed_observation_path_for(
            result.observation,
            return_url: params[:return_url],
            return_text: params[:return_text],
            ogo_consult: 1
          ), notice: "Consult OG started. This page will update when processing finishes."
        else
          redirect_back fallback_location: new_organization_observation_path(organization),
                        alert: result.error
        end
      end

      def status
        authorize @observation, :consult_ogo_quality?
        run = @observation.latest_ogo_quality_consultation
        if run.nil?
          return render json: { status: "none", id: nil, elapsed_seconds: 0, stale: false, slow: false }
        end

        render json: OgConsultations::StatusPayload.for_consultation(run, error_message: run.error_message)
      end

      private

      def set_observation
        if params[:id].to_s == "new"
          redirect_to new_organization_observation_path(organization), alert: "Save observees and a story first."
          return
        end

        @observation = organization.observations.find(params[:id])
      end

      def observation_from_id
        return nil if params[:id].blank? || params[:id].to_s == "new"

        organization.observations.find(params[:id])
      end

      def observation_params
        params.fetch(:observation, {}).permit(
          :story, :observation_type, :privacy_level, :primary_feeling, :secondary_feeling
        )
      end

      def typed_observation_path_for(observation, options = {})
        path_options = { draft_id: observation.id, ogo_consult: options[:ogo_consult] }.compact
        path_options[:return_url] = options[:return_url] if options[:return_url].present?
        path_options[:return_text] = options[:return_text] if options[:return_text].present?
        path_options[:goal_id] = observation.goal_id if observation.goal_id.present?

        case observation.observation_type
        when "kudos"
          new_kudos_organization_observations_path(organization, path_options)
        when "feedback"
          new_feedback_organization_observations_path(organization, path_options)
        when "quick_note"
          new_quick_note_organization_observations_path(organization, path_options)
        else
          new_organization_observation_path(organization, path_options)
        end
      end
    end
  end
end
