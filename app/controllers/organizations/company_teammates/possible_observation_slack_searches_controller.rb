# frozen_string_literal: true

class Organizations::CompanyTeammates::PossibleObservationSlackSearchesController < Organizations::OrganizationNamespaceBaseController
  include Organizations::AssignsViewableTeammates

  before_action :authenticate_person!
  before_action :set_subject_teammate
  before_action :set_one_on_one_link
  before_action :assign_viewable_teammates_context
  before_action :set_search, only: %i[show destroy search_status download_raw_results]
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
    @batches = @search.message_batches.in_position_order
    if @search.search_status == "completed" && @batches.empty? && @search.raw_results_file.attached?
      PossibleObservationSlackSearches::CreateMessageBatches.call(search: @search)
      @batches = @search.message_batches.reload.in_position_order
    end
    load_unified_review_context if @search.search_status == "completed" && @batches.any?
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

  def search_status
    authorize @search, :show?
    status = @search.search_status.to_s
    render json: OgConsultations::StatusPayload.for_heartbeat(
      record: @search,
      status: status,
      search_error: @search.search_error,
      messages_count: @search.messages_count
    )
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

  def load_unified_review_context
    @observation_type_options = [
      ["Kudos", "kudos"],
      ["Feedback", "feedback"]
    ]
    load_teammate_options
    @latest_consultation_by_batch_id = {}
    @duplicate_observations_by_batch_id = {}
    @suggested_rateable_names_by_batch_id = {}

    @batches.each do |batch|
      @latest_consultation_by_batch_id[batch.id] = OgConsultation.latest_for(
        subject: batch,
        kind: OgConsultation::KIND_OGO_SEARCH_SLACK
      )
      next unless batch.extraction_status == "completed"

      duplicates = {}
      batch.extraction_items.each do |item|
        key = "#{item[:channel_id]}|#{item[:ts]}"
        next if item[:channel_id].blank? || item[:ts].blank?
        next if duplicates.key?(key)

        duplicates[key] = PossibleObservationSlackSearches::DuplicateObservationsForMessage.call(
          organization: organization,
          channel_id: item[:channel_id],
          message_ts: item[:ts]
        )
      end
      @duplicate_observations_by_batch_id[batch.id] = duplicates
      @suggested_rateable_names_by_batch_id[batch.id] = suggested_rateable_names_for(batch)
    end
  end

  def suggested_rateable_names_for(batch)
    names = {}
    items = batch.extraction_items
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
        names["#{type}:#{record.id}"] = name
      end
    end
    names
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
end
