# frozen_string_literal: true

class Organizations::CompanyTeammates::PossibleObservationSlackSearchBatchesController < Organizations::OrganizationNamespaceBaseController
  include Organizations::AssignsViewableTeammates

  before_action :authenticate_person!
  before_action :set_subject_teammate
  before_action :set_one_on_one_link
  before_action :assign_viewable_teammates_context
  before_action :set_search
  before_action :set_batch, only: %i[
    show update extract re_extract re_extract_with_stronger_model extraction_status
    create_draft_observations
  ]
  after_action :verify_authorized

  def show
    authorize @batch
    redirect_to search_anchor_path, status: :see_other
  end

  # Save all: actualize every row's status — dismiss dismissed rows, promote included
  # rows to draft OGOs, and leave "reviewing" rows as unprocessed candidates.
  # When dismiss_item_id is present (Dismiss now), quick-dismiss that single row instead.
  def update
    authorize @batch
    items = normalize_items_param(items_param)
    if params[:dismiss_item_id].present?
      dismiss_single!(items, params[:dismiss_item_id].to_s)
    else
      save_all!(items)
    end
  rescue ActionController::ParameterMissing
    redirect_to batch_path, alert: "Invalid candidate data."
  end

  # Backward-compatible route; behaves like Save all.
  def create_draft_observations
    authorize @batch
    items = normalize_items_param(items_param)
    save_all!(items)
  rescue ActionController::ParameterMissing
    redirect_to batch_path, alert: "Invalid candidate data."
  end

  def extract
    authorize @batch, :extract?
    @batch.update!(extraction_status: "pending", extraction_error: nil, extractions: {})
    PossibleObservationSlackSearchExtractionJob.perform_later(@batch.id)
    redirect_to batch_path, notice: "Consult OG started — finding potential OGOs in the background."
  end

  def re_extract
    authorize @batch, :re_extract?
    @batch.update!(extraction_status: "pending", extraction_error: nil, extractions: {})
    PossibleObservationSlackSearchExtractionJob.perform_later(@batch.id)
    redirect_to batch_path, notice: "Consult OG started again — finding potential OGOs in the background."
  end

  def re_extract_with_stronger_model
    authorize @batch, :re_extract_with_stronger_model?
    @batch.update!(extraction_status: "pending", extraction_error: nil, extractions: {})
    PossibleObservationSlackSearchExtractionJob.perform_later(
      @batch.id,
      model_id: Llm::SlackMomentsExtractor.stronger_model_id
    )
    redirect_to batch_path,
                notice: "Consult OG started with a stronger model — finding potential OGOs in the background."
  end

  def extraction_status
    authorize @batch, :extraction_status?
    status = @batch.extraction_status.to_s
    consultation = OgConsultation.latest_for(
      subject: @batch,
      kind: OgConsultation::KIND_OGO_SEARCH_SLACK
    )
    payload =
      if consultation
        OgConsultations::StatusPayload.for_consultation(
          consultation,
          status: status,
          search_error: @batch.extraction_error,
          messages_count: @batch.messages_count
        )
      else
        OgConsultations::StatusPayload.for_heartbeat(
          record: @batch,
          status: status,
          search_error: @batch.extraction_error,
          messages_count: @batch.messages_count
        )
      end
    render json: payload
  end

  private

  def set_subject_teammate
    @teammate = find_organization_teammate!(params[:company_teammate_id])
  end

  def set_one_on_one_link
    @one_on_one_link = @teammate&.one_on_one_link || OneOnOneLink.new(teammate: @teammate)
    authorize @one_on_one_link, :ogos?
  end

  def assign_viewable_teammates_context
    return unless @teammate

    assign_viewable_teammates_context!(selected_teammate: @teammate)
  end

  def set_search
    @search = PossibleObservationSlackSearch
              .where(organization: organization, subject_company_teammate: @teammate)
              .find(params[:possible_observation_slack_search_id])
  end

  def set_batch
    @batch = @search.message_batches.find(params[:id])
  end

  def batch_path
    search_anchor_path
  end

  def search_anchor_path
    organization_company_teammate_possible_observation_slack_search_path(
      organization,
      @teammate,
      @search,
      anchor: "consultation-#{@batch.position}"
    )
  end

  def items_param
    params[:items] || params.dig(:possible_observation_slack_search_batch, :items)
  end

  def included_item?(item)
    ActiveModel::Type::Boolean.new.cast(item["include"])
  end

  # One-at-a-time quick dismiss (Dismiss now). Saves the current on-screen state of
  # every row (no promotion) and force-dismisses the targeted row.
  def dismiss_single!(items, target_id)
    matched = false
    items = items.map do |item|
      next item unless item["id"].to_s == target_id

      matched = true
      item["include"] = false
      item["dismissed_at"] = item["dismissed_at"].presence || Time.current.iso8601
      item["dismissed_by_company_teammate_id"] =
        item["dismissed_by_company_teammate_id"].presence || current_company_teammate&.id
      item
    end
    @batch.replace_extraction_items!(items) if items.any?
    redirect_to batch_path, notice: matched ? "Candidate dismissed." : "Candidates saved."
  end

  def save_all!(items)
    if items.empty?
      redirect_to batch_path, alert: "No candidate rows to save."
      return
    end

    invalid_rows = items.select do |item|
      included_item?(item) && item["observation_id"].blank? &&
        (item["responder_company_teammate_id"].blank? || item["subject_company_teammate_id"].blank?)
    end
    if invalid_rows.any?
      redirect_to batch_path, alert: "Rows set to Include must have both observer and subject selected."
      return
    end

    @batch.replace_extraction_items!(items)
    dismissed_count = items.count { |item| item["dismissed_at"].present? }

    promotable = items.any? { |item| included_item?(item) && item["observation_id"].blank? }
    unless promotable
      redirect_to batch_path, notice: saved_notice(dismissed_count)
      return
    end

    authorize @batch, :create_draft_observations?
    result = PossibleObservationSlackSearches::BatchCreateDraftObservationsService.call(
      batch: @batch.reload,
      creator: current_company_teammate
    )

    if result.ok?
      payload = result.value
      notice_parts = []
      notice_parts << "Created #{payload[:created]} draft OGO#{"s" if payload[:created] != 1}." if payload[:created].positive?
      notice_parts << "#{payload[:skipped_already]} already had drafts." if payload[:skipped_already].positive?
      if payload[:soft_duplicate_count].to_i.positive?
        notice_parts << "#{payload[:soft_duplicate_count]} may already link to the same Slack message (soft warning)."
      end
      notice_parts << dismissed_summary(dismissed_count) if dismissed_count.positive?
      if payload[:errors].any?
        redirect_to batch_path,
                    alert: [notice_parts.presence&.join(" "), payload[:errors].join(" ")].compact.join(" ")
      elsif notice_parts.empty?
        redirect_to batch_path, notice: "Candidates saved."
      else
        redirect_to batch_path, notice: notice_parts.join(" ")
      end
    else
      redirect_to batch_path, alert: Array(result.error).join(", ")
    end
  end

  def saved_notice(dismissed_count)
    return "Candidates saved." unless dismissed_count.positive?

    "Candidates saved. #{dismissed_summary(dismissed_count)}"
  end

  def dismissed_summary(count)
    "#{count} candidate#{"s" unless count == 1} currently dismissed."
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
      h = if h.respond_to?(:permit)
        h.permit(
          :id, :state, :quote, :summary, :short_quote, :full_quote, :kind,
          :speaker_label, :recipient_label,
          :responder_company_teammate_id, :subject_company_teammate_id,
          :observer_unknown, :observee_unknown,
          :channel_id, :ts, :permalink, :slack_user_id,
          :suggested_rateable_type, :suggested_rateable_id, :suggested_rating, :suggested_goal_id,
          :suggested_rateable_name, :association_reason, :rating_reason, :target_is_subject,
          :confidence, :observation_id,
          :dismissed_at, :dismissed_by_company_teammate_id
        ).to_h
      else
        h.stringify_keys
      end
      out = h.stringify_keys
      out["observer_unknown"] = out["responder_company_teammate_id"].blank?
      out["observee_unknown"] = out["subject_company_teammate_id"].blank?
      apply_state!(out)
      out
    end
  end

  STATES = %w[needs_processed included dismissed].freeze

  # Reconcile the row's single tri-state (needs_processed | included | dismissed) into
  # the stored flags. Preserves the original dismissal timestamp/actor on re-save.
  def apply_state!(out)
    state = out.delete("state").to_s
    state = "needs_processed" unless STATES.include?(state)

    out["include"] = (state == "included")

    if state == "dismissed"
      out["dismissed_at"] = out["dismissed_at"].presence || Time.current.iso8601
      out["dismissed_by_company_teammate_id"] =
        out["dismissed_by_company_teammate_id"].presence || current_company_teammate&.id
    else
      out["dismissed_at"] = nil
      out["dismissed_by_company_teammate_id"] = nil
    end
    out
  end
end
