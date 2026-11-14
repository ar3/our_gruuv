# frozen_string_literal: true

module Api
  # HTTP mint endpoint for Zapier/etc. Auth: same Bearer tokens as MCP (ogmcp_… / ogoat_…).
  class FeedbackRequestMintsController < ActionController::API
    def create
      auth = Mcp::Authenticate.call(authorization_header: request.authorization.to_s)
      unless auth.ok?
        response.set_header('WWW-Authenticate', 'Bearer')
        return render json: { ok: false, error: auth.error, error_code: 'not_authorized' }, status: :unauthorized
      end

      result = AgentTools::MintFeedbackLink.call(
        context: auth.context,
        observed: params[:observed],
        observer: params[:observer],
        topics: params[:topics],
        feedback_request_id: params[:feedback_request_id],
        observed_teammate_id: params[:observed_teammate_id],
        observed_email: params[:observed_email],
        observed_phone: params[:observed_phone],
        observer_person_id: params[:observer_person_id],
        observer_teammate_id: params[:observer_teammate_id],
        observer_email: params[:observer_email],
        observer_phone: params[:observer_phone]
      )

      if result.ok?
        render json: { ok: true, data: result.data }, status: :ok
      else
        status =
          case result.error_code
          when 'not_authorized' then :forbidden
          when 'not_found' then :not_found
          when 'ambiguous' then :unprocessable_entity
          else :unprocessable_entity
          end
        render json: { ok: false, error: result.error, error_code: result.error_code }, status: status
      end
    end
  end
end
