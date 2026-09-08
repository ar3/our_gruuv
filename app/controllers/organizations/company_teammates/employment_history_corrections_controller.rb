# frozen_string_literal: true

class Organizations::CompanyTeammates::EmploymentHistoryCorrectionsController < Organizations::OrganizationNamespaceBaseController
  before_action :require_authentication
  before_action :set_teammate
  after_action :verify_authorized

  def show
    authorize @teammate, :correct_employment_history?
    load_page_data
  end

  def update_tenure
    authorize @teammate, :correct_employment_history?
    tenure = find_tenure!(params[:tenure_id])

    result = EmploymentTenures::CorrectHistoryService.update_tenure(
      teammate: @teammate,
      tenure: tenure,
      attrs: tenure_params.to_h.symbolize_keys
    )

    if result.ok?
      flash[:notice] = success_notice('Tenure updated.', result.value[:adjustments])
      redirect_to organization_company_teammate_employment_history_correction_path(@organization, @teammate)
    else
      flash.now[:alert] = result.error
      load_page_data
      render :show, status: :unprocessable_entity
    end
  end

  def prepend
    authorize @teammate, :correct_employment_history?

    result = EmploymentTenures::CorrectHistoryService.prepend(
      teammate: @teammate,
      attrs: tenure_params.to_h.symbolize_keys
    )

    if result.ok?
      flash[:notice] = success_notice('Earliest tenure added.', result.value[:adjustments])
      redirect_to organization_company_teammate_employment_history_correction_path(@organization, @teammate)
    else
      flash.now[:alert] = result.error
      load_page_data
      @prepend_tenure = EmploymentTenure.new(tenure_params)
      render :show, status: :unprocessable_entity
    end
  end

  def connect_gap
    authorize @teammate, :correct_employment_history?
    earlier = find_tenure!(params[:earlier_tenure_id])
    later = find_tenure!(params[:later_tenure_id])

    result = EmploymentTenures::CorrectHistoryService.connect_gap(
      teammate: @teammate,
      earlier_tenure: earlier,
      later_tenure: later
    )

    if result.ok?
      flash[:notice] = success_notice('Tenures connected.', result.value[:adjustments])
      redirect_to organization_company_teammate_employment_history_correction_path(@organization, @teammate)
    else
      flash.now[:alert] = result.error
      load_page_data
      render :show, status: :unprocessable_entity
    end
  end

  private

  def set_teammate
    @teammate = find_organization_teammate!(params[:company_teammate_id])
  end

  def find_tenure!(id)
    @teammate.employment_tenures.where(company: @organization).find(id)
  end

  def load_page_data
    @employment_tenures = @teammate.employment_tenures
                                  .where(company: @organization)
                                  .includes(:position, :manager_teammate)
                                  .order(:started_at)
    @metrics = EmploymentTenures::HistoryMetrics.call(tenures: @employment_tenures)
    @managers = @organization.teammates.includes(:person).order('people.last_name, people.first_name')
    @positions = @organization.positions.unarchived.includes(:title, :position_level)
    @prepend_tenure ||= EmploymentTenure.new(
      company: @organization,
      started_at: suggested_prepend_start,
      ended_at: @employment_tenures.first&.started_at
    )
    @person = @teammate.person
  end

  def suggested_prepend_start
    earliest = @employment_tenures.first&.started_at
    return 1.year.ago if earliest.blank?

    earliest - 1.year
  end

  def tenure_params
    params.require(:employment_tenure).permit(
      :position_id,
      :manager_teammate_id,
      :started_at,
      :ended_at,
      :employment_change_notes
    )
  end

  def success_notice(prefix, adjustments)
    return prefix if adjustments.blank?

    "#{prefix} #{adjustments.join(' ')}"
  end

  def require_authentication
    return if current_person

    redirect_to root_path, alert: 'Please log in to correct employment history.'
  end
end
