# frozen_string_literal: true

class Organizations::TalentDensityController < Organizations::OrganizationNamespaceBaseController
  VALID_MATRICES = %w[
    stances
    visualization
    guidance_matrix
    assignment_rating_alignment
  ].freeze

  before_action :authenticate_person!
  after_action :verify_authorized

  def show
    if policy(@organization).talent_density?
      authorize @organization, :talent_density?
      params[:matrix] = "stances"
      load_shared_filter_context
      load_working_page
    else
      authorize @organization, :talent_density_explainer?
      @explainer_only = true
    end
  end

  def update
    authorize @organization, :talent_density?
    params[:matrix] = "stances"
    load_shared_filter_context

    unless @access.manager_selectable?(@selected_manager)
      raise Pundit::NotAuthorizedError, "Not allowed to rate this manager's team"
    end

    report_by_id = scoped_teammates_excluding.index_by(&:id)

    ActiveRecord::Base.transaction do
      submitted_stance_attrs.each do |teammate_id, attrs|
        teammate = report_by_id[teammate_id]
        next unless teammate
        next if teammate.id == current_company_teammate.id
        next unless @access.can_edit?(teammate)

        stance = TalentDensityStance.find_or_initialize_by(company_teammate: teammate)
        stance.company = company
        authorize stance, :update?
        stance.stance = attrs[:stance]
        stance.notes = attrs[:notes]
        stance.save!
      end
    end

    redirect_to organization_talent_density_path(@organization, talent_density_redirect_filter_params),
                notice: "Talent Density saved."
  rescue ActiveRecord::RecordInvalid
    flash.now[:alert] = "Could not save Talent Density. Check the form and try again."
    load_working_page
    render :show, status: :unprocessable_entity
  end

  def visualization
    return unless require_working_access

    params[:matrix] = "visualization"
    load_shared_filter_context
    teammates = scoped_teammates_excluding
    @query = TalentDensity::VisualizationQuery.new(teammates: teammates)
  end

  def guidance_matrix
    return unless require_working_access

    params[:matrix] = "guidance_matrix"
    load_shared_filter_context
    teammates = scoped_teammates_excluding
    @query = TalentDensity::GuidanceMatrixQuery.new(teammates: teammates)
  end

  def assignment_rating_alignment
    return unless require_working_access

    params[:matrix] = "assignment_rating_alignment"
    load_shared_filter_context
    teammates = scoped_teammates_excluding
    @query = TalentDensity::AssignmentRatingAlignmentQuery.new(teammates: teammates)
  end

  def filters
    return unless require_working_access

    load_shared_filter_context
    @exclude_candidates = @access.active_teammates_for_exclude.to_a
  end

  private

  def require_working_access
    unless policy(@organization).talent_density?
      authorize @organization, :talent_density_explainer?
      redirect_to organization_talent_density_path(@organization)
      return false
    end

    authorize @organization, :talent_density?
    true
  end

  def load_working_page
    @reports = scoped_teammates_excluding
    stance_by_teammate_id = TalentDensityStance.where(company_teammate_id: @reports.map(&:id)).index_by(&:company_teammate_id)
    @rows = decorate_talent_density_rows(@reports, stance_by_teammate_id)
  end

  def load_shared_filter_context
    load_access
    merge_stored_visualization_filters_into_params
    resolve_selected_manager
    @scope = params[:scope].to_s == "hierarchy" ? "hierarchy" : "directs"
    @display = params[:display].to_s == "names" ? "names" : "dots"
    @matrix = normalize_matrix(params[:matrix])
    @exclude_ids = Array(params[:exclude_teammate_ids]).map(&:to_i).uniq.reject(&:zero?)
    @excluded_teammates = excluded_teammates_for(@exclude_ids)
    assign_manager_filter_options
    store_visualization_filters
  end

  def normalize_matrix(value)
    key = value.to_s
    VALID_MATRICES.include?(key) ? key : "stances"
  end

  def excluded_teammates_for(ids)
    return [] if ids.blank?

    CompanyTeammate.where(id: ids)
      .joins(:person)
      .includes(:person)
      .order("people.last_name ASC", "people.first_name ASC")
      .to_a
  end

  def scoped_teammates_excluding
    return [] unless @selected_manager

    @access.teammates_in_scope(@selected_manager, scope: @scope)
      .where.not(id: @exclude_ids)
      .to_a
  end

  def assign_manager_filter_options
    @manager_filter_options = @access.selectable_managers.map do |manager|
      [manager.person&.display_name, "CompanyTeammate_#{manager.id}"]
    end
    @current_manager_filter = manager_filter_param
  end

  def visualization_filter_session_key
    "talent_density_viz_filters_#{@organization.id}"
  end

  def merge_stored_visualization_filters_into_params
    return if visualization_filters_in_params?

    stored = session[visualization_filter_session_key]
    return unless stored.is_a?(Hash)

    params[:manager_id] = stored["manager_id"] if stored["manager_id"].present?
    params[:scope] = stored["scope"] if stored["scope"].present?
    params[:display] = stored["display"] if stored["display"].present?
    params[:matrix] = stored["matrix"] if stored["matrix"].present? && params[:matrix].blank?
    params[:exclude_teammate_ids] = stored["exclude_teammate_ids"] if stored["exclude_teammate_ids"].present?
  end

  def visualization_filters_in_params?
    params[:manager_id].present? ||
      params[:scope].present? ||
      params[:display].present? ||
      params[:applied].present? ||
      params[:exclude_teammate_ids].present?
  end

  def store_visualization_filters
    session[visualization_filter_session_key] = {
      "manager_id" => manager_filter_param,
      "scope" => @scope,
      "display" => @display,
      "matrix" => @matrix,
      "exclude_teammate_ids" => @exclude_ids
    }
  end

  def talent_density_redirect_filter_params
    {
      manager_id: manager_filter_param,
      scope: @scope,
      display: @display,
      matrix: @matrix,
      exclude_teammate_ids: @exclude_ids,
      applied: 1
    }
  end

  def load_access
    @access = TalentDensity::Access.new(
      viewer: current_company_teammate,
      organization: @organization,
      org_wide: org_wide_viewer?
    )
  end

  def org_wide_viewer?
    policy(@organization).manage_employment? || policy(@organization).admin_bypass?
  end

  def resolve_selected_manager
    requested_id = parsed_manager_id
    requested = requested_id && CompanyTeammate.find_by(id: requested_id)
    @selected_manager = if @access.manager_selectable?(requested)
      requested
    else
      @access.default_manager
    end
  end

  def parsed_manager_id
    match = params[:manager_id].to_s.match(/\ACompanyTeammate_(\d+)\z/)
    match && match[1].to_i
  end

  def manager_filter_param
    if @selected_manager && parsed_manager_id == @selected_manager.id
      params[:manager_id]
    elsif @selected_manager
      "CompanyTeammate_#{@selected_manager.id}"
    end
  end

  def submitted_stance_attrs
    raw = params[:stances]
    return {} unless raw.respond_to?(:to_unsafe_h)

    raw.to_unsafe_h.each_with_object({}) do |(teammate_id, attrs), acc|
      id = teammate_id.to_i
      next if id <= 0
      next unless attrs.is_a?(Hash)

      stance = attrs["stance"].to_s
      stance = nil unless TalentDensityStance.stances.key?(stance)
      acc[id] = { stance: stance, notes: attrs["notes"].to_s }
    end
  end

  def decorate_talent_density_rows(teammates, stance_by_teammate_id)
    ids = teammates.map(&:id)
    tenures_by_id = EmploymentTenure
      .where(company: company, ended_at: nil, teammate_id: ids)
      .includes(:seat, :manager_teammate, position: [:title, :position_level])
      .order(:id)
      .group_by(&:teammate_id)
      .transform_values(&:first)

    finalized_by_id = PositionCheckIn
      .where(teammate_id: ids)
      .closed
      .order(official_check_in_completed_at: :desc)
      .group_by(&:teammate_id)
      .transform_values(&:first)

    open_by_id = PositionCheckIn.where(teammate_id: ids).open.index_by(&:teammate_id)

    teammates.map do |teammate|
      tenure = tenures_by_id[teammate.id]
      {
        teammate: teammate,
        stance: stance_by_teammate_id[teammate.id] || TalentDensityStance.new(company_teammate: teammate, company: company),
        tenure: tenure,
        latest_finalized: finalized_by_id[teammate.id],
        open_check_in: open_by_id[teammate.id],
        viewers: @access.viewers_for_subject(teammate, manager: tenure&.manager_teammate).to_a
      }
    end
  end
end
