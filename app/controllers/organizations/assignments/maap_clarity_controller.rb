# frozen_string_literal: true

module Organizations
  module Assignments
    class MaapClarityController < Organizations::AssignmentsController
      skip_before_action :set_assignment
      before_action :set_maap_assignment

      def show
        authorize @assignment, :run_clarity?
        assign_assignments_for_maap_clarity_switcher
        @run = MaapAgentRun.includes(:maap_recommendation_acceptances).find_by(
          subject: @assignment,
          agent_kind: MaapAgentRun::AGENT_KIND_ASSIGNMENT_CLARITY
        )
        @accepted_maap_recommendation_ids =
          @run ? @run.maap_recommendation_acceptances.pluck(:recommendation_id) : []
        render layout: determine_layout
      end

      def run
        authorize @assignment, :run_clarity?
        record = MaapAgentRun.find_or_initialize_by(
          subject: @assignment,
          agent_kind: MaapAgentRun::AGENT_KIND_ASSIGNMENT_CLARITY
        )
        record.maap_recommendation_acceptances.destroy_all if record.persisted?
        record.assign_attributes(
          status: 'pending',
          clarity_rating: nil,
          clarity_score: nil,
          clarity_recommendations: [],
          output_text: nil,
          error_message: nil,
          prompt_version: Maap::Prompts::MAAP_PROMPTS_VERSION,
          triggered_by_teammate: current_company_teammate
        )
        record.save!
        AssignmentClarityJob.perform_later(@assignment.id, record.id)
        redirect_to maap_clarity_organization_assignment_path(@organization, @assignment),
                    notice: 'Consult OG started. This page will update when processing finishes.'
      end

      def status
        authorize @assignment, :run_clarity?
        run = MaapAgentRun.find_by(
          subject: @assignment,
          agent_kind: MaapAgentRun::AGENT_KIND_ASSIGNMENT_CLARITY
        )
        if run.nil?
          return render json: { status: 'none', id: nil, elapsed_seconds: 0, stale: false, slow: false }
        end

        render json: status_json_for(run)
      end

      def accept_recommendation
        authorize @assignment, :accept_clarity_recommendation?
        run = MaapAgentRun.find_by!(
          subject: @assignment,
          agent_kind: MaapAgentRun::AGENT_KIND_ASSIGNMENT_CLARITY
        )
        unless run.status == 'completed' && run.output_text.present?
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

        acceptance = MaapRecommendationAcceptance.find_or_initialize_by(
          maap_agent_run: run,
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

      def status_json_for(run)
        status = run.status.to_s
        reference_time =
          case status
          when 'processing'
            run.updated_at || run.created_at
          when 'pending'
            run.updated_at || run.created_at
          else
            run.updated_at || run.created_at
          end
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
