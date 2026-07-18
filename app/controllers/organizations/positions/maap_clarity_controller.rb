# frozen_string_literal: true

module Organizations
  module Positions
    class MaapClarityController < Organizations::PositionsController
      skip_before_action :set_position
      before_action :set_maap_position

      def show
        authorize @position, :run_clarity?
        assign_positions_for_maap_clarity_switcher
        @run = @position.latest_position_clarity_consultation
        render layout: determine_layout
      end

      def run
        authorize @position, :run_clarity?
        org_id = @position.company&.id || @position.title.company_id
        consultation = OgConsultation.create!(
          kind: OgConsultation::KIND_POSITION_CLARITY,
          subject: @position,
          organization_id: org_id,
          triggered_by_teammate: current_company_teammate,
          status: 'pending',
          billable: true,
          prompt_version: Maap::Prompts::MAAP_PROMPTS_VERSION,
          units_total: 1,
          units_completed: 0
        )
        result = PositionClarityResult.create!(og_consultation: consultation)
        consultation.update!(result: result)
        PositionClarityJob.perform_later(@position.id, consultation.id)
        redirect_to maap_clarity_organization_position_path(@organization, @position),
                    notice: 'Consult OG started. This page will update when processing finishes.'
      end

      def status
        authorize @position, :run_clarity?
        run = @position.latest_position_clarity_consultation
        if run.nil?
          return render json: { status: 'none', id: nil, elapsed_seconds: 0, stale: false, slow: false }
        end

        render json: status_json_for(run)
      end

      private

      def set_maap_position
        @position = policy_scope(Position).find(params[:id])
      end

      def assign_positions_for_maap_clarity_switcher
        positions = policy_scope(Position).unarchived
          .includes(:position_level, title: [:department, :position_major_level])
          .left_joins(title: :department)
          .order(
            Arel.sql('CASE WHEN titles.department_id IS NULL THEN 0 ELSE 1 END'),
            'departments.name',
            'titles.external_title',
            'position_levels.level'
          )
        groups = positions.group_by { |p| p.title.department&.display_name || 'Company-wide' }
        @positions_by_department_for_maap_switcher = {}
        @positions_by_department_for_maap_switcher['Company-wide'] = groups['Company-wide'] if groups['Company-wide'].present?
        (groups.keys - ['Company-wide']).sort.each do |label|
          @positions_by_department_for_maap_switcher[label] = groups[label]
        end
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
