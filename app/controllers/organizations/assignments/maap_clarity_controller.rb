# frozen_string_literal: true

module Organizations
  module Assignments
    class MaapClarityController < Organizations::AssignmentsController
      skip_before_action :set_assignment
      before_action :set_maap_assignment

      def show
        authorize @assignment, :run_clarity?
        @run = MaapAgentRun.find_by(
          subject: @assignment,
          agent_kind: MaapAgentRun::AGENT_KIND_ASSIGNMENT_CLARITY
        )
        render layout: determine_layout
      end

      def run
        authorize @assignment, :run_clarity?
        record = MaapAgentRun.find_or_initialize_by(
          subject: @assignment,
          agent_kind: MaapAgentRun::AGENT_KIND_ASSIGNMENT_CLARITY
        )
        record.assign_attributes(
          status: 'pending',
          clarity_rating: nil,
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

      private

      def set_maap_assignment
        @assignment = policy_scope(Assignment).where(company: @organization).find(params[:id])
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
