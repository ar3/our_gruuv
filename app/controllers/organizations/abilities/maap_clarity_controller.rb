# frozen_string_literal: true

module Organizations
  module Abilities
    class MaapClarityController < Organizations::AbilitiesController
      skip_before_action :set_ability
      before_action :set_maap_ability
      before_action :assign_abilities_for_maap_clarity_switcher, only: :show

      def show
        authorize @ability, :run_clarity?
        @run = @ability.latest_ability_clarity_consultation
        render layout: determine_layout
      end

      def run
        authorize @ability, :run_clarity?
        entry = OgConsultations::Kinds.fetch(OgConsultation::KIND_ABILITY_CLARITY)
        consultation = OgConsultation.create!(
          kind: entry.kind,
          subject: @ability,
          organization_id: @ability.company_id,
          triggered_by_teammate: current_company_teammate,
          status: 'pending',
          billable: entry.billable,
          prompt_version: Maap::Prompts::MAAP_PROMPTS_VERSION,
          units_total: 1,
          units_completed: 0
        )
        result = entry.result_class.create!(og_consultation: consultation)
        consultation.update!(result: result)
        entry.job_class.perform_later(@ability.id, consultation.id)
        redirect_to maap_clarity_organization_ability_path(@organization, @ability),
                    notice: 'Consult OG started. This page will update when processing finishes.'
      end

      def status
        authorize @ability, :run_clarity?
        run = @ability.latest_ability_clarity_consultation
        if run.nil?
          return render json: { status: 'none', id: nil, elapsed_seconds: 0, stale: false, slow: false }
        end

        render json: status_json_for(run)
      end

      private

      def set_maap_ability
        @ability = policy_scope(Ability).where(company: @organization).find(params[:id])
      end

      def assign_abilities_for_maap_clarity_switcher
        scope = policy_scope(Ability).where(company: @organization).unarchived.includes(:department)
        abilities_array = scope.left_joins(:department).order(
          Arel.sql("COALESCE(departments.name, '')"),
          'abilities.name'
        ).to_a
        grouped = abilities_array.group_by(&:department)
        @abilities_by_department_for_maap_switcher = grouped.sort_by { |dept, _| dept ? [1, dept.display_name] : [0, ''] }.to_h
        @abilities_by_department_for_maap_switcher.transform_values! { |list| list.sort_by(&:name) }
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
