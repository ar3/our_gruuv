# frozen_string_literal: true

module Organizations
  module Assignments
    class MaapClarityController < Organizations::AssignmentsController
      skip_before_action :set_assignment
      before_action :set_maap_assignment

      def show
        authorize @assignment, :run_clarity?
        assign_assignments_for_maap_clarity_switcher
        @run = @assignment.latest_assignment_clarity_consultation
        @accepted_maap_recommendation_ids =
          if @run&.result.is_a?(AssignmentClarityResult)
            @run.result.assignment_clarity_recommendation_acceptances.pluck(:recommendation_id)
          else
            []
          end
        render layout: determine_layout
      end

      def run
        authorize @assignment, :run_clarity?
        consultation = OgConsultation.create!(
          kind: OgConsultation::KIND_ASSIGNMENT_CLARITY,
          subject: @assignment,
          organization_id: @assignment.company_id,
          triggered_by_teammate: current_company_teammate,
          status: 'pending',
          billable: true,
          prompt_version: Maap::Prompts::MAAP_PROMPTS_VERSION,
          units_total: 1,
          units_completed: 0
        )
        result = AssignmentClarityResult.create!(
          og_consultation: consultation,
          consult_focus: sanitized_consult_focus_param,
          clarity_recommendations: []
        )
        consultation.update!(result: result)
        AssignmentClarityJob.perform_later(@assignment.id, consultation.id)
        redirect_to maap_clarity_organization_assignment_path(@organization, @assignment),
                    notice: 'Consult OG started. This page will update when processing finishes.'
      end

      def status
        authorize @assignment, :run_clarity?
        run = @assignment.latest_assignment_clarity_consultation
        if run.nil?
          return render json: { status: 'none', id: nil, elapsed_seconds: 0, stale: false, slow: false }
        end

        render json: status_json_for(run)
      end

      def accept_recommendation
        authorize @assignment, :accept_clarity_recommendation?
        run = @assignment.latest_assignment_clarity_consultation
        unless run&.status == 'completed' && run.output_text.present? && run.result.is_a?(AssignmentClarityResult)
          redirect_to maap_clarity_organization_assignment_path(@organization, @assignment),
                      alert: 'Accept is only available after a completed Consult OG run.'
          return
        end

        rid = params.require(:recommendation_id).to_s
        valid_ids = Array(run.clarity_recommendations).map { |h| h.stringify_keys['id'] }.compact
        unless valid_ids.include?(rid)
          redirect_to maap_clarity_organization_assignment_path(@organization, @assignment),
                      alert: 'That recommendation is not part of the latest Consult OG run.'
          return
        end

        acceptance = AssignmentClarityRecommendationAcceptance.find_or_initialize_by(
          assignment_clarity_result: run.result,
          recommendation_id: rid
        )
        if acceptance.new_record?
          acceptance.teammate = current_company_teammate
          acceptance.save!
        end

        redirect_to maap_clarity_organization_assignment_path(@organization, @assignment),
                    notice: 'Recommendation marked as accepted.'
      end

      private

      def set_maap_assignment
        @assignment = policy_scope(Assignment).where(company: @organization).find(params[:id])
      end

      def assign_assignments_for_maap_clarity_switcher
        scope = policy_scope(Assignment).where(company: @organization).unarchived.includes(:department)
        assignments_array = scope.left_joins(:department).order(
          Arel.sql("COALESCE(departments.name, '')"),
          'assignments.title'
        ).to_a
        grouped = assignments_array.group_by(&:department)
        @assignments_by_department_for_maap_switcher = grouped.sort_by { |dept, _| dept ? [1, dept.display_name] : [0, ''] }.to_h
        @assignments_by_department_for_maap_switcher.transform_values! { |list| list.sort_by { |a| a.title.to_s.downcase } }
      end

      def sanitized_consult_focus_param
        raw = params[:consult_focus].to_s.strip
        return nil if raw.blank?

        raw.truncate(8_000, omission: '…')
      end

      def status_json_for(run)
        status = run.status.to_s
        reference_time = run.started_at || run.updated_at || run.created_at
        elapsed_seconds = [(Time.current - reference_time).to_i, 0].max
        stale = status == 'processing' && elapsed_seconds > 240
        slow = %w[pending processing].include?(status) && elapsed_seconds > 90

        {
          id: run.id,
          status: status,
          clarity_rating: run.clarity_rating,
          clarity_score: run.clarity_score,
          error_message: run.error_message,
          elapsed_seconds: elapsed_seconds,
          stale: stale,
          slow: slow,
          updated_at: run.updated_at&.iso8601
        }
      end
    end
  end
end
