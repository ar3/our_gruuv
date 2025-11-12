class Organizations::Teammates::PositionController < Organizations::OrganizationNamespaceBaseController
  layout 'authenticated-v2-0'
  before_action :authenticate_person!
  before_action :set_teammate
  after_action :verify_authorized

  def show
    authorize @teammate.person, :view_check_ins?
    
    @check_ins = PositionCheckIn
      .where(teammate: @teammate)
      .includes(:finalized_by, :manager_completed_by, :employment_tenure)
      .order(check_in_started_on: :desc)
    
    @current_employment = @teammate.employment_tenures.active.first
    @open_check_in = PositionCheckIn.where(teammate: @teammate).open.first
  end

  private

  def set_teammate
    @teammate = organization.teammates.find(params[:teammate_id])
  end
end

