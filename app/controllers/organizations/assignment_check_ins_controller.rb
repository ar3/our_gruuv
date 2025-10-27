class Organizations::AssignmentCheckInsController < Organizations::OrganizationNamespaceBaseController
  layout 'authenticated-v2-0'
  before_action :authenticate_person!
  before_action :set_person
  before_action :set_assignment
  after_action :verify_authorized

  def history
    authorize @person, :view_check_ins?
    
    @teammate = @person.teammates.find_by(organization: organization)
    @check_ins = AssignmentCheckIn
      .where(teammate: @teammate, assignment: @assignment)
      .includes(:manager_completed_by, :finalized_by)
      .order(check_in_started_on: :desc)
  end

  private

  def set_person
    @person = Person.find(params[:person_id])
  end

  def set_assignment
    @assignment = Assignment.find(params[:id])
  end
end

