# frozen_string_literal: true

module Organizations
  module Teammates
    class CheckInPeriodBriefConsultsController < Organizations::OrganizationNamespaceBaseController
      CHECK_IN_KINDS = {
        "assignment" => AssignmentCheckIn,
        "aspiration" => AspirationCheckIn,
        "position" => PositionCheckIn
      }.freeze

      before_action :authenticate_person!
      before_action :set_teammate
      before_action :set_check_in
      after_action :verify_authorized

      def create
        authorize_check_in_access!
        unless current_company_teammate
          return render_error("Sign in as a teammate in this organization.", status: :unprocessable_entity)
        end

        result = CheckIns::StartPeriodBriefConsult.call(
          organization: organization,
          triggered_by_teammate: current_company_teammate,
          check_in: @check_in
        )

        if result.ok?
          render json: status_json(result.consultation).merge(ok: true)
        else
          render_error(result.error, status: :unprocessable_entity)
        end
      end

      def show
        authorize_check_in_access!
        run = @check_in.latest_period_brief_consultation
        if run.nil?
          return render json: {
            status: "none",
            id: nil,
            elapsed_seconds: 0,
            stale: false,
            slow: false,
            polling: false
          }
        end

        render json: status_json(run)
      end

      private

      def set_teammate
        @teammate = find_organization_teammate!(params[:teammate_id])
      end

      def set_check_in
        kind = params[:check_in_kind].to_s
        klass = CHECK_IN_KINDS[kind]
        unless klass
          head :bad_request
          return
        end

        @check_in_kind = kind
        @check_in = klass.where(company_teammate: @teammate).find(params[:check_in_id])
      end

      def authorize_check_in_access!
        if @check_in_kind == "position"
          authorize @teammate, :view_check_ins?, policy_class: CompanyTeammatePolicy
        else
          authorize @teammate.person, :view_check_ins?, policy_class: PersonPolicy
        end
      end

      def status_json(consultation)
        extras = {
          error_message: consultation.error_message,
          polling: consultation.in_flight?
        }

        if consultation.status == "completed" && consultation.result.is_a?(CheckInPeriodBriefResult)
          extras[:output_text] = consultation.result.copy_text
          extras[:completed_at] = consultation.completed_at&.iso8601
          extras[:completed_at_display] = completed_at_display(consultation)
        end

        OgConsultations::StatusPayload.for_consultation(consultation, **extras)
      end

      def completed_at_display(consultation)
        stamp = consultation.completed_at || consultation.created_at
        return nil if stamp.blank?

        zone = TimezoneService.iana_identifier(current_person&.timezone_or_default)
        stamp.in_time_zone(zone).strftime("%B %-d, %Y %-l:%M %p")
      rescue StandardError
        stamp.strftime("%B %-d, %Y %-l:%M %p")
      end

      def render_error(message, status:)
        render json: { ok: false, error: message }, status: status
      end
    end
  end
end
