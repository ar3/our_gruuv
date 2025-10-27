class Organizations::PositionCheckInsController < Organizations::OrganizationNamespaceBaseController
  layout 'authenticated-v2-0'
  before_action :authenticate_person!
  before_action :set_person
  after_action :verify_authorized

  def history
    authorize @person, :view_check_ins?
    
    @teammate = @person.teammates.find_by(organization: organization)
    @check_ins = PositionCheckIn
      .where(teammate: @teammate)
      .includes(:finalized_by, :manager_completed_by, :employment_tenure)
      .order(check_in_started_on: :desc)
  end

  private

  def set_person
    @person = Person.find(params[:person_id])
  end
end

