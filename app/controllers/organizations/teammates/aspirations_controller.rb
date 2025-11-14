class Organizations::Teammates::AspirationsController < Organizations::OrganizationNamespaceBaseController
  layout 'authenticated-v2-0'
  before_action :authenticate_person!
  before_action :set_teammate
  before_action :set_aspiration
  after_action :verify_authorized

  def show
    authorize @teammate.person, :view_check_ins?, policy_class: PersonPolicy
    
    # Load all check-ins (full history)
    @check_ins = AspirationCheckIn
      .where(teammate: @teammate, aspiration: @aspiration)
      .includes(:manager_completed_by, :finalized_by)
      .order(check_in_started_on: :desc)
    
    # Load current/open check-in
    @open_check_in = AspirationCheckIn.find_or_create_open_for(@teammate, @aspiration)
  end

  private

  def set_teammate
    @teammate = organization.teammates.find(params[:teammate_id])
  end

  def set_aspiration
    @aspiration = Aspiration.find(params[:id])
  end
end

