# frozen_string_literal: true

class Organizations::CompanyTeammates::PossibleObservationSlackSearchesController < Organizations::OrganizationNamespaceBaseController
  include Organizations::AssignsViewableTeammates

  before_action :authenticate_person!
  before_action :set_subject_teammate
  before_action :set_one_on_one_link
  before_action :assign_viewable_teammates_context
  before_action :set_search, only: %i[
    show update destroy search_status extraction_status extract re_extract download_raw_results
  ]
  after_action :verify_authorized

  def create
    authorize PossibleObservationSlackSearch.new(
      organization: organization,
      creator_company_teammate: current_company_teammate,
      subject_company_teammate: @teammate
    )

    unless current_company_teammate&.has_slack_search_identity?
      redirect_to ogos_source_from_slack_organization_company_teammate_path(organization, @teammate),
                  alert: "Connect Slack (search) before running a search."
      return
    end

    window_days = permitted_window_days
    search = PossibleObservationSlackSearch.new(
      organization: organization,
      creator_company_teammate: current_company_teammate,
      subject_company_teammate: @teammate,
      window_days: window_days,
      display_name: default_display_name(window_days),
      search_status: "pending",
      extraction_status: "ready"
    )

    if search.save
      PossibleObservationSlackSearchJob.perform_later(search.id)
      redirect_to organization_company_teammate_possible_observation_slack_search_path(
        organization,
        @teammate,
        search
      ), notice: "Slack search started. Results will appear when the run finishes."
    else
      redirect_to ogos_source_from_slack_organization_company_teammate_path(organization, @teammate),
                  alert: search.errors.full_messages.to_sentence
    end
  end

  def show
    authorize @search
    @casual_name = @teammate.person.casual_name
    @active_tab = :source_from_slack
    @messages = @search.search_status == "completed" ? @search.raw_messages : []
    load_review_context if @search.extraction_status == "completed"
  end

  def update
    authorize @search
    items = normalize_items_param(items_param)
    if items.empty?
      redirect_to organization_company_teammate_possible_observation_slack_search_path(organization, @teammate, @search),
                  alert: "No candidate rows to save."
      return
    end

    invalid_rows = items.select do |item|
      ActiveModel::Type::Boolean.new.cast(item["include"]) &&
        (item["responder_company_teammate_id"].blank? || item["subject_company_teammate_id"].blank?)
    end
    if invalid_rows.any?
      redirect_to organization_company_teammate_possible_observation_slack_search_path(organization, @teammate, @search),
                  alert: "Rows marked include must have both observer and subject selected."
      return
    end

    @search.replace_extraction_items!(items)
    redirect_to organization_company_teammate_possible_observation_slack_search_path(organization, @teammate, @search),
                notice: "Candidates saved. Creating draft OGOs comes in a later step."
  rescue ActionController::ParameterMissing
    redirect_to organization_company_teammate_possible_observation_slack_search_path(organization, @teammate, @search),
                alert: "Invalid candidate data."
  end

  def download_raw_results
    authorize @search, :show?
    unless @search.raw_results_file.attached?
      redirect_to organization_company_teammate_possible_observation_slack_search_path(organization, @teammate, @search),
                  alert: "No raw results file is available for download."
      return
    end

    redirect_to rails_blob_path(@search.raw_results_file, disposition: "attachment")
  end

  def extract
    authorize @search, :extract?
    unless @search.search_status == "completed"
      redirect_to organization_company_teammate_possible_observation_slack_search_path(organization, @teammate, @search),
                  alert: "Finish the Slack search before extracting candidates."
      return
    end

    @search.update!(extraction_status: "pending", extraction_error: nil, extractions: {})
    PossibleObservationSlackSearchExtractionJob.perform_later(@search.id)
    redirect_to organization_company_teammate_possible_observation_slack_search_path(organization, @teammate, @search),
                notice: "Finding noteworthy OGO candidates in the background."
  end

  def re_extract
    authorize @search, :re_extract?
    @search.update!(extraction_status: "pending", extraction_error: nil, extractions: {})
    PossibleObservationSlackSearchExtractionJob.perform_later(@search.id)
    redirect_to organization_company_teammate_possible_observation_slack_search_path(organization, @teammate, @search),
                notice: "Re-extraction started."
  end

  def search_status
    authorize @search, :show?
    status = @search.search_status.to_s
    render json: status_payload(status: status, error: @search.search_error)
  end

  def extraction_status
    authorize @search, :extraction_status?
    status = @search.extraction_status.to_s
    render json: status_payload(status: status, error: @search.extraction_error)
  end

  def destroy
    authorize @search
    @search.destroy!
    redirect_to ogos_source_from_slack_organization_company_teammate_path(organization, @teammate),
                notice: "Slack search deleted."
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
              .find(params[:id])
  end

  def permitted_window_days
    days = params.dig(:possible_observation_slack_search, :window_days).to_i
    return days if PossibleObservationSlackSearch::ALLOWED_WINDOW_DAYS.include?(days)

    PossibleObservationSlackSearch::DEFAULT_WINDOW_DAYS
  end

  def default_display_name(window_days)
    "Slack search about #{@teammate.person.casual_name} (last #{window_days} days) — #{Time.current.strftime('%Y-%m-%d %H:%M')}"
  end

  def status_payload(status:, error:)
    reference_time =
      case status
      when "processing"
        @search.updated_at || @search.created_at
      when "pending"
        @search.created_at
      else
        @search.updated_at || @search.created_at
      end
    elapsed_seconds = [(Time.current - reference_time).to_i, 0].max
    {
      id: @search.id,
      status: status,
      search_error: error,
      messages_count: @search.messages_count,
      elapsed_seconds: elapsed_seconds,
      stale: status == "processing" && elapsed_seconds > 120,
      slow: %w[pending processing].include?(status) && elapsed_seconds > 60,
      updated_at: @search.updated_at
    }
  end

  def load_review_context
    load_teammate_options
    @observation_type_options = [
      ["Kudos", "kudos"],
      ["Feedback", "feedback"],
      ["Quick note", "quick_note"]
    ]
    @duplicate_observations_by_key = {}
    @search.extraction_items.each do |item|
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
    params[:items] || params.dig(:possible_observation_slack_search, :items)
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
          :suggested_rateable_type, :suggested_rateable_id, :suggested_rating, :suggested_goal_id
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
