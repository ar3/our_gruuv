# frozen_string_literal: true

module Organizations
  module HealthNudgeActions
    extend ActiveSupport::Concern

    private

    def assign_health_nudge_context!(health_object:, spotlight_stats:)
      @health_nudge_object = health_object.to_s
      @health_nudge_config = HealthNudges::Registry.fetch(@health_nudge_object)
      @health_nudge_manager = resolve_health_nudge_manager_teammate
      return unless @health_nudge_manager

      @health_nudge_skip_level = HealthNudges::Service.skip_level_for(
        manager_teammate: @health_nudge_manager,
        organization: @organization
      )
      @health_nudge_recipients_manager = HealthNudges::Service.recipient_teammates(
        manager_teammate: @health_nudge_manager,
        nudger_company_teammate: current_company_teammate,
        organization: @organization,
        recipient_scope: "manager"
      )
      @health_nudge_recipients_manager_and_skip = HealthNudges::Service.recipient_teammates(
        manager_teammate: @health_nudge_manager,
        nudger_company_teammate: current_company_teammate,
        organization: @organization,
        recipient_scope: "manager_and_skip"
      )
      @health_nudge_message = HealthNudges::Message.new(
        health_object: @health_nudge_object,
        organization: @organization,
        manager_teammate: @health_nudge_manager,
        spotlight_stats: spotlight_stats
      )
      @last_health_nudge = HealthNudges::Service.last_delivered_for(
        manager_teammate: @health_nudge_manager,
        health_object: @health_nudge_object
      )
    end

    def perform_health_nudge!(health_object:, spotlight_stats:, redirect_path:, employee_entries: [])
      config = HealthNudges::Registry.fetch(health_object)
      manager = resolve_health_nudge_manager_teammate
      unless manager
        redirect_to redirect_path, alert: "Select a specific manager to send a #{config[:label]} nudge."
        return
      end

      result = HealthNudges::Service.call(
        organization: @organization,
        health_object: health_object,
        manager_teammate: manager,
        nudger_company_teammate: current_company_teammate,
        spotlight_stats: spotlight_stats,
        recipient_scope: params[:recipient_scope],
        employee_entries: employee_entries
      )

      if result.ok?
        redirect_to redirect_path, notice: config[:notice]
      else
        redirect_to redirect_path, alert: result.error
      end
    end

    def resolve_health_nudge_manager_teammate
      return nil unless params[:manager_id].to_s =~ /\ACompanyTeammate_(\d+)\z/

      mgr_id = Regexp.last_match(1).to_i
      return nil unless health_nudge_manager_filter_viewable?(mgr_id)

      CompanyTeammate.for_organization_hierarchy(@organization).find_by(id: mgr_id)
    end

    def health_nudge_manager_filter_viewable?(_manager_id)
      raise NotImplementedError, "#{self.class.name} must implement #health_nudge_manager_filter_viewable?"
    end
  end
end
