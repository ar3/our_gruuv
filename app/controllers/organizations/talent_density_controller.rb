# frozen_string_literal: true

class Organizations::TalentDensityController < Organizations::OrganizationNamespaceBaseController
  before_action :authenticate_person!
  after_action :verify_authorized

  def show
    if policy(@organization).talent_density?
      authorize @organization, :talent_density?
      load_working_page
    else
      authorize @organization, :talent_density_explainer?
      @explainer_only = true
    end
  end

  def update
    authorize @organization, :talent_density?
    load_access
    resolve_selected_manager

    unless @access.manager_selectable?(@selected_manager)
      raise Pundit::NotAuthorizedError, "Not allowed to rate this manager's team"
    end

    reports = @access.reports_for(@selected_manager)
    report_by_id = reports.index_by(&:id)

    ActiveRecord::Base.transaction do
      submitted_stance_attrs.each do |teammate_id, attrs|
        teammate = report_by_id[teammate_id]
        next unless teammate
        next if teammate.id == current_company_teammate.id

        stance = TalentDensityStance.find_or_initialize_by(company_teammate: teammate)
        stance.company = company
        authorize stance, :update?
        stance.stance = attrs[:stance]
        stance.notes = attrs[:notes]
        stance.save!
      end
    end

    redirect_to organization_talent_density_path(@organization, manager_id: manager_filter_param),
                notice: "Talent Density saved."
  rescue ActiveRecord::RecordInvalid
    flash.now[:alert] = "Could not save Talent Density. Check the form and try again."
    load_working_page
    render :show, status: :unprocessable_entity
  end

  private

  def load_working_page
    load_access
    resolve_selected_manager
    @reports = @selected_manager ? @access.reports_for(@selected_manager).to_a : []
    stance_by_teammate_id = TalentDensityStance.where(company_teammate_id: @reports.map(&:id)).index_by(&:company_teammate_id)
    @rows = decorate_talent_density_rows(@reports, stance_by_teammate_id)
    @manager_filter_options = @access.selectable_managers.map do |manager|
      [manager.person&.display_name, "CompanyTeammate_#{manager.id}"]
    end
    @current_manager_filter = manager_filter_param
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
