class Organizations::PeopleController < Organizations::OrganizationNamespaceBaseController
  layout 'authenticated-v2-0'
  before_action :authenticate_person!
  before_action :set_person
  after_action :verify_authorized

  def complete_picture
    authorize @person, :manager?
    # Complete picture view - detailed view for managers to see person's position, assignments, and milestones
    @employment_tenures = @person.employment_tenures.includes(:company, :position, :manager)
                                 .order(started_at: :desc)
                                 .decorate
    @current_employment = @employment_tenures.find { |t| t.ended_at.nil? }
    @current_organization = @current_employment&.company
  end

  private

  def set_person
    @person = Person.find(params[:id])
  end
end
