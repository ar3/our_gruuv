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
    @casual_name = @teammate.person.casual_name
    @active_tab = :source_from_slack
    @messages = @batch.messages
    @latest_consultation = OgConsultation.latest_for(
      subject: @batch,
      kind: OgConsultation::KIND_OGO_SEARCH_SLACK
    )
    load_review_context if @batch.extraction_status == "completed"
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
    organization_company_teammate_possible_observation_slack_search_batch_path(
      organization, @teammate, @search, @batch
    )
  end

  def load_review_context
    load_teammate_options
    load_suggested_rateable_names
    @observation_type_options = [
      ["Kudos", "kudos"],
      ["Feedback", "feedback"]
    ]
    @duplicate_observations_by_key = {}
    @batch.extraction_items.each do |item|
      key = "#{item[:channel_id]}|#{item[:ts]}"
      next if item[:channel_id].blank? || item[:ts].blank?
      next if @duplicate_observations_by_key.key?(key)

      @duplicate_observations_by_key[key] = PossibleObservationSlackSearches::DuplicateObservationsForMessage.call(
        organization: organization,
        channel_id: item[:channel_id],
        message_ts: item[:ts]
      )
    end
  end

  def load_suggested_rateable_names
    @suggested_rateable_names_by_key = {}
    items = @batch.extraction_items

    {
      "Assignment" => Assignment,
      "Ability" => Ability,
      "Aspiration" => Aspiration
    }.each do |type, model|
      ids = items.filter_map do |item|
        item[:suggested_rateable_id].to_i if item[:suggested_rateable_type] == type
      end
      model.where(id: ids).find_each do |record|
        name = record.respond_to?(:title) ? record.title : record.name
        @suggested_rateable_names_by_key["#{type}:#{record.id}"] = name
      end
    end
  end

  def load_teammate_options
    @teammates_for_select =
      CompanyTeammate.employed
                     .where(organization: current_company_teammate.organization)
                     .includes(:person, employment_tenures: { position: { title: :department } })
                     .order("people.last_name, people.first_name")
    @teammates_grouped_for_select = teammates_grouped_by_department_for_select(@teammates_for_select)
  end

  def teammates_grouped_by_department_for_select(teammates)
    list = teammates.respond_to?(:to_a) ? teammates.to_a : teammates
    by_department = list.group_by do |teammate|
      active_tenure = teammate.employment_tenures.find { |et| et.ended_at.nil? && et.company_id == organization.id }
      active_tenure&.position&.title&.department
    end

    by_department.keys.sort_by { |department| department.nil? ? "" : department.display_name }.map do |department|
      label = department.nil? ? "No department" : department.display_name
      options = by_department[department]
                  .sort_by { |teammate| [teammate.person.last_name.to_s, teammate.person.first_name.to_s] }
                  .map { |teammate| [teammate.person.display_name, teammate.id] }
      [label, options]
    end
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
