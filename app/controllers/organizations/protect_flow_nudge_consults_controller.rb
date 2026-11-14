# frozen_string_literal: true

module Organizations
  class ProtectFlowNudgeConsultsController < Organizations::OrganizationNamespaceBaseController
    include Organizations::ProtectFlowTeammateFiltering
    include Organizations::HealthNudgeActions

    before_action :require_authentication

    def create
      authorize @organization, :protect_flow?
      manager = resolve_health_nudge_manager_teammate
      unless manager
        return redirect_back_to_protect_flow(alert: "Select a specific manager to Consult OG.")
      end

      if restore_requested?
        draft = HealthNudges::DraftStore.for(
          person: current_person,
          organization: @organization,
          manager_teammate: manager
        )
        draft.restore_consultation!
        return redirect_back_to_protect_flow(notice: "Restored today’s Consult OG draft.")
      end

      if restore_suggested_requested?
        draft = HealthNudges::DraftStore.for(
          person: current_person,
          organization: @organization,
          manager_teammate: manager
        )
        # Ensure suggested exists then restore
        load_plan_for!(manager)
        stats = HealthNudges::Service.spotlight_stats_from_protect_flow_plan(@plan)
        message = HealthNudges::Message.new(
          health_object: "protect_flow",
          organization: @organization,
          manager_teammate: manager,
          spotlight_stats: stats,
          employee_count: @plan[:people].size
        )
        suggested = HealthNudges::SuggestedBody.call(message: message, people: @plan[:people])
        draft.ensure_suggested!(suggested)
        draft.restore_suggested!
        return redirect_back_to_protect_flow(notice: "Restored suggested nudge draft.")
      end

      load_plan_for!(manager)
      stats = HealthNudges::Service.spotlight_stats_from_protect_flow_plan(@plan)
      result = HealthNudges::StartProtectFlowNudgeConsult.call(
        organization: @organization,
        manager_teammate: manager,
        nudger_teammate: current_company_teammate,
        people: @plan[:people],
        spotlight_stats: stats
      )

      if result.ok?
        redirect_back_to_protect_flow(notice: "Consult OG started. This panel will update when processing finishes.")
      else
        redirect_back_to_protect_flow(alert: result.error)
      end
    end

    def status
      authorize @organization, :protect_flow?
      manager = resolve_health_nudge_manager_teammate
      run =
        if manager
          OgConsultation
            .where(
              kind: OgConsultation::KIND_PROTECT_FLOW_NUDGE,
              subject: manager,
              organization: @organization,
              triggered_by_teammate: current_company_teammate
            )
            .where("created_at >= ?", Time.zone.now.beginning_of_day)
            .latest_first
            .first
        end

      if run.nil?
        return render json: { status: "none", id: nil, elapsed_seconds: 0, stale: false, slow: false }
      end

      render json: OgConsultations::StatusPayload.for_consultation(run, error_message: run.error_message)
    end

    private

    def require_authentication
      return if current_person

      redirect_unauthenticated_to_login!(message: "Please log in.", flash_key: :alert)
    end

    def health_nudge_manager_filter_viewable?(manager_id)
      protect_flow_manager_viewable?(manager_id)
    end

    def restore_requested?
      params[:restore_consultation].present? || params[:intent].to_s == "restore_consultation"
    end

    def restore_suggested_requested?
      params[:restore_suggested].present? || params[:intent].to_s == "restore_suggested"
    end

    def load_plan_for!(_manager)
      teammates = filtered_teammates_for_protect_flow.to_a
      store = ProtectFlow::WeekSnapshotStore.for(person: current_person, organization: @organization)
      @plan = ProtectFlow::PlanBuilder.call(
        organization: @organization,
        week_store: store,
        teammates: teammates,
        week_start: params[:week_start].presence,
        viewer: current_company_teammate
      )
    end

    def redirect_back_to_protect_flow(notice: nil, alert: nil)
      opts = { manager_id: params[:manager_id], nudge: 1 }.compact
      opts[:week_start] = params[:week_start] if params[:week_start].present?
      redirect_to organization_protect_flow_path(
        @organization,
        **opts,
        anchor: "healthNudge-protect_flow"
      ), notice: notice, alert: alert
    end
  end
end
