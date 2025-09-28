class Organizations::PeopleController < Organizations::OrganizationNamespaceBaseController
  layout 'authenticated-v2-0'
  before_action :authenticate_person!
  before_action :set_person
  after_action :verify_authorized

  def complete_picture
    authorize @person, :manager?
    # Complete picture view - detailed view for managers to see person's position, assignments, and milestones
    # Filter by the organization from the route
    @employment_tenures = @person.employment_tenures.includes(:company, :position, :manager)
                                 .where(company: organization)
                                 .order(started_at: :desc)
                                 .decorate
    @current_employment = @employment_tenures.find { |t| t.ended_at.nil? }
    @current_organization = organization
    
    # Filter assignments to only show those for this organization
    @assignment_tenures = @person.assignment_tenures.active
                                .joins(:assignment)
                                .where(assignments: { company: organization })
                                .includes(:assignment)
    
    # Filter milestones to only show those for abilities in this organization
    @person_milestones = @person.person_milestones
                                .joins(:ability)
                                .where(abilities: { organization: organization })
                                .includes(:ability)
  end

  private

  def set_person
    @person = Person.find(params[:id])
  end
end
