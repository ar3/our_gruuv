# frozen_string_literal: true

module Organizations
  module CompanyTeammates
    class MaapTeammateGrowthController < Organizations::CompanyTeammatesController
      def show
        authorize @teammate, :run_teammate_growth?, policy_class: CompanyTeammatePolicy
        assign_teammates_for_maap_growth_switcher
        @run = @teammate.latest_teammate_growth_consultation
        render layout: determine_layout
      end

      def run
        authorize @teammate, :run_teammate_growth?, policy_class: CompanyTeammatePolicy
        consultation = OgConsultation.create!(
          kind: OgConsultation::KIND_TEAMMATE_GROWTH,
          subject: @teammate,
          organization_id: organization.id,
          triggered_by_teammate: current_company_teammate,
          status: 'pending',
          billable: true,
          prompt_version: Maap::Prompts::MAAP_PROMPTS_VERSION,
          units_total: 1,
          units_completed: 0
        )
        result = TeammateGrowthResult.create!(og_consultation: consultation)
        consultation.update!(result: result)
        TeammateGrowthJob.perform_later(@teammate.id, organization.id, consultation.id)
        redirect_to maap_teammate_growth_organization_company_teammate_path(organization, @teammate),
                    notice: 'Consult OG started. This page will update when processing finishes.'
      end

      def status
        authorize @teammate, :run_teammate_growth?, policy_class: CompanyTeammatePolicy
        run = @teammate.latest_teammate_growth_consultation
        if run.nil?
          return render json: { status: 'none', id: nil, elapsed_seconds: 0, stale: false, slow: false }
        end

        render json: status_json_for(run)
      end

      private

      def assign_teammates_for_maap_growth_switcher
        assign_viewable_teammates_context!(selected_teammate: @teammate)
        filtered = {}
        @viewable_teammate_groups.each do |dept_name, teammates|
          allowed = teammates.select do |tm|
            CompanyTeammatePolicy.new(pundit_user, tm).run_teammate_growth?
          end
          filtered[dept_name] = allowed if allowed.any?
        end
        @viewable_teammate_groups = filtered
      end

      def status_json_for(run)
        OgConsultations::StatusPayload.for_consultation(
          run,
          clarity_rating: run.clarity_rating,
          error_message: run.error_message
        )
      end
    end
  end
end
