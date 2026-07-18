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
  ]
  after_action :verify_authorized

  def show
    authorize @batch
    redirect_to search_anchor_path, status: :see_other
  end

  def update
    authorize @batch
    items = normalize_items_param(items_param)
    if items.empty?
      redirect_to batch_path, alert: "No candidate rows to save."
      return
    end

    invalid_rows = items.select do |item|
      ActiveModel::Type::Boolean.new.cast(item["include"]) &&
        (item["responder_company_teammate_id"].blank? || item["subject_company_teammate_id"].blank?)
    end
    if invalid_rows.any?
      redirect_to batch_path, alert: "Rows marked include must have both observer and subject selected."
      return
    end

    @batch.replace_extraction_items!(items)
    redirect_to batch_path, notice: "Candidates saved. Creating draft OGOs comes in a later step."
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
          :id, :include, :quote, :summary, :short_quote, :full_quote, :kind,
          :speaker_label, :recipient_label,
          :responder_company_teammate_id, :subject_company_teammate_id,
          :observer_unknown, :observee_unknown,
          :channel_id, :ts, :permalink, :slack_user_id,
          :suggested_rateable_type, :suggested_rateable_id, :suggested_rating, :suggested_goal_id,
          :suggested_rateable_name, :association_reason, :rating_reason, :target_is_subject,
          :confidence
        ).to_h
      else
        h.stringify_keys
      end
      out = h.stringify_keys
      out["include"] = (out["include"].to_s == "1")
      out["observer_unknown"] = out["responder_company_teammate_id"].blank?
      out["observee_unknown"] = out["subject_company_teammate_id"].blank?
      out
    end
  end
end
