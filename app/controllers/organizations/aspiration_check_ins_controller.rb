class Organizations::AspirationCheckInsController < Organizations::OrganizationNamespaceBaseController
  layout 'authenticated-v2-0'
  before_action :authenticate_person!
  before_action :set_person
  before_action :set_aspiration
  after_action :verify_authorized

  def history
    authorize @person, :view_check_ins?
    
    @teammate = @person.teammates.find_by(organization: organization)
    @check_ins = AspirationCheckIn
      .where(teammate: @teammate, aspiration: @aspiration)
      .includes(:manager_completed_by, :finalized_by)
      .order(check_in_started_on: :desc)
  end

  private

  def set_person
    @person = Person.find(params[:person_id])
  end

  def set_aspiration
    @aspiration = Aspiration.find(params[:id])
  end
end

