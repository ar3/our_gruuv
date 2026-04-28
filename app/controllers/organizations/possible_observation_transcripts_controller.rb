# frozen_string_literal: true

module Organizations
  class PossibleObservationTranscriptsController < OrganizationNamespaceBaseController
    before_action :set_transcript, only: [:show, :update, :destroy, :extraction_status, :review_feedback_requests, :batch_create_feedback_requests, :re_extract]

    after_action :verify_authorized
    after_action :verify_policy_scoped, only: [:index]

    def index
      authorize PossibleObservationTranscript
      scope = policy_scope(PossibleObservationTranscript).recent_first.includes(creator_company_teammate: :person)
      scope = scope.where(creator_company_teammate_id: current_company_teammate.id) if params[:mine] == '1'
      @transcripts = scope
      @mine_only = params[:mine] == '1'
    end

    def new
      @transcript = PossibleObservationTranscript.new(
        organization: organization,
        creator_company_teammate: current_company_teammate,
        display_name: default_display_name,
        extractions: {},
        extraction_status: 'pending'
      )
      authorize @transcript
    end

    def create
      @transcript = PossibleObservationTranscript.new(
        organization: organization,
        creator_company_teammate: current_company_teammate,
        display_name: transcript_create_params[:display_name],
        extractions: {},
        extraction_status: 'pending'
      )
      authorize @transcript

      file = params.dig(:possible_observation_transcript, :transcript_file)
      if file.blank?
        @transcript.errors.add(:transcript_file, "can't be blank")
        render :new, status: :unprocessable_entity
        return
      end

      @transcript.transcript_file.attach(file)

      if @transcript.save
        PossibleObservationTranscriptExtractionJob.perform_later(@transcript.id)
        redirect_to organization_possible_observation_transcript_path(organization, @transcript),
                      notice: 'Transcript uploaded. Extraction is running in the background.'
      else
        render :new, status: :unprocessable_entity
      end
    end

    def show
      authorize @transcript
      load_teammate_options
      @observation_type_options = observation_type_options
    end

    def update
      authorize @transcript
      items = normalize_items_param(items_param)
      if items.empty?
        redirect_to organization_possible_observation_transcript_path(organization, @transcript),
                    alert: 'No extraction rows to save.'
        return
      end

      invalid_rows = items.select do |item|
        ActiveModel::Type::Boolean.new.cast(item['include']) &&
          (item['responder_company_teammate_id'].blank? || item['subject_company_teammate_id'].blank?)
      end
      if invalid_rows.any?
        row_ids = invalid_rows.map { |item| item['id'] }.join(', ')
        redirect_to organization_possible_observation_transcript_path(organization, @transcript),
                    alert: "Rows marked include must have both responder and subject selected before continuing. Problem rows: #{row_ids}"
        return
      end

      @transcript.replace_extraction_items!(items)
      redirect_to review_feedback_requests_organization_possible_observation_transcript_path(organization, @transcript),
                  notice: 'Observations were saved. Review feedback requests next.'
    rescue ActionController::ParameterMissing
      redirect_to organization_possible_observation_transcript_path(organization, @transcript),
                  alert: 'Invalid extraction data.'
    end

    def review_feedback_requests
      authorize @transcript, :batch_create_feedback_requests?
      @items = @transcript.extraction_items.select { |item| ActiveModel::Type::Boolean.new.cast(item[:include]) }
      teammate_ids = @items.flat_map do |item|
        [item[:subject_company_teammate_id].presence, item[:responder_company_teammate_id].presence]
      end.compact.map(&:to_i).uniq
      @teammates_by_id = CompanyTeammate.includes(:person).where(id: teammate_ids).index_by(&:id)
    end

    def extraction_status
      authorize @transcript, :show?
      status = @transcript.extraction_status.to_s
      reference_time =
        case status
        when 'processing'
          @transcript.updated_at || @transcript.created_at
        when 'pending'
          @transcript.created_at
        else
          @transcript.updated_at || @transcript.created_at
        end
      elapsed_seconds = [(Time.current - reference_time).to_i, 0].max
      stale = status == 'processing' && elapsed_seconds > 120
      slow = %w[pending processing].include?(status) && elapsed_seconds > 60

      render json: {
        id: @transcript.id,
        status: status,
        extraction_error: @transcript.extraction_error,
        elapsed_seconds: elapsed_seconds,
        stale: stale,
        slow: slow,
        updated_at: @transcript.updated_at
      }
    end

    def destroy
      authorize @transcript
      unless @transcript.deletable?
        redirect_to organization_possible_observation_transcript_path(organization, @transcript),
                    alert: 'Delete feedback requests for this transcript before deleting it.'
        return
      end

      @transcript.destroy!
      redirect_to organization_possible_observation_transcripts_path(organization),
                  notice: 'Transcript was deleted.'
    rescue ActiveRecord::DeleteRestrictionError
      redirect_to organization_possible_observation_transcript_path(organization, @transcript),
                  alert: 'Cannot delete while feedback requests exist for this transcript.'
    end

    def batch_create_feedback_requests
      authorize @transcript, :batch_create_feedback_requests?

      result = PossibleObservationTranscripts::BatchCreateFeedbackRequestsService.call(
        transcript: @transcript,
        creator: current_company_teammate,
        impersonating_teammate: impersonating_teammate,
        extraction_ids: params[:extraction_ids],
        send_notifications_now: params[:send_notifications_now].to_s == '1'
      )

      if result.ok?
        msg = +"Created #{result.value[:created]} feedback request(s)."
        if result.value[:notifications_requested]
          msg << " Sent #{result.value[:notifications_sent]} notification(s)." if result.value[:notifications_sent].to_i.positive?
          msg << " #{result.value[:notification_errors].join(' ')}" if result.value[:notification_errors].present?
        end
        msg << " #{result.value[:errors].join(' ')}" if result.value[:errors].any?
        redirect_to organization_possible_observation_transcript_path(organization, @transcript), notice: msg
      else
        redirect_to review_feedback_requests_organization_possible_observation_transcript_path(organization, @transcript), alert: result.error
      end
    end

    def re_extract
      authorize @transcript, :re_extract?
      unless @transcript.deletable?
        redirect_to organization_possible_observation_transcript_path(organization, @transcript),
                    alert: 'Remove linked feedback requests before re-running extraction.'
        return
      end

      @transcript.update!(extraction_status: 'pending', extraction_error: nil, extractions: {})
      PossibleObservationTranscriptExtractionJob.perform_later(@transcript.id)
      redirect_to organization_possible_observation_transcript_path(organization, @transcript),
                    notice: 'Re-extraction started.'
    end

    private

    def set_transcript
      @transcript = policy_scope(PossibleObservationTranscript).find(params[:id])
    end

    def default_display_name
      "Meeting Transcript #{Time.zone.today.strftime('%Y-%m-%d')}"
    end

    def transcript_create_params
      params.require(:possible_observation_transcript).permit(:display_name)
    end

    def items_param
      params[:items] || params.dig(:possible_observation_transcript, :items)
    end

    def normalize_items_param(raw)
      return [] if raw.blank?

      list =
        case raw
        when ActionController::Parameters
          raw.to_unsafe_h.sort_by { |k, _| k.to_s.to_i }.map(&:last)
        when Hash
          raw.sort_by { |k, _| k.to_s.to_i }.map(&:last)
        else
          []
        end

      list.map do |h|
        h = h.respond_to?(:permit) ? h.permit(
          :id, :include, :quote, :summary, :short_quote, :full_quote, :kind, :speaker_label, :recipient_label,
          :responder_company_teammate_id, :subject_company_teammate_id,
          :observer_unknown, :observee_unknown, :feedback_request_id
        ).to_h : h.stringify_keys
        out = h.stringify_keys
        out['include'] = (out['include'].to_s == '1')
        # Keep unknown flags aligned with current teammate selections.
        out['observer_unknown'] = out['responder_company_teammate_id'].blank?
        out['observee_unknown'] = out['subject_company_teammate_id'].blank?
        out
      end
    end

    def load_teammate_options
      @teammates_for_select =
        CompanyTeammate.employed
                       .where(organization: current_company_teammate.organization)
                       .includes(:person, employment_tenures: { position: { title: :department } })
                       .order('people.last_name, people.first_name')
      @teammates_grouped_for_select = teammates_grouped_by_department_for_select(@teammates_for_select)
    end

    def observation_type_options
      [
        ['Kudos', 'kudos'],
        ['Feedback', 'feedback'],
        ['Quick note', 'quick_note']
      ]
    end

    # Build grouped options for teammate dropdowns by active position department.
    def teammates_grouped_by_department_for_select(teammates)
      list = teammates.respond_to?(:to_a) ? teammates.to_a : teammates
      by_department = list.group_by do |teammate|
        active_tenure = teammate.employment_tenures.find { |et| et.ended_at.nil? && et.company_id == organization.id }
        active_tenure&.position&.title&.department
      end

      by_department.keys.sort_by { |department| department.nil? ? '' : department.display_name }.map do |department|
        label = department.nil? ? 'No department' : department.display_name
        options = by_department[department]
                    .sort_by { |teammate| [teammate.person.last_name.to_s, teammate.person.first_name.to_s] }
                    .map { |teammate| [teammate.person.display_name, teammate.id] }
        [label, options]
      end
    end
  end
end
