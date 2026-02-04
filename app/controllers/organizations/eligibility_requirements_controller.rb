class Organizations::EligibilityRequirementsController < Organizations::OrganizationNamespaceBaseController
  before_action :authenticate_person!
  before_action :set_selectable_teammates, only: [:index, :show]
  before_action :set_positions, only: [:index, :show]
  before_action :set_position, only: [:show]
  before_action :set_teammate, only: [:show]

  def index
    authorize :eligibility_requirement, :index?

    if params[:position_id].present?
      redirect_to organization_eligibility_requirement_path(
        organization,
        params[:position_id],
        teammate_id: params[:teammate_id]
      )
    end
  end

  def show
    authorize :eligibility_requirement, :show?

    unless teammate_allowed?(@teammate)
      flash[:alert] = "You don't have access to that teammate."
      redirect_to organization_eligibility_requirements_path(organization)
      return
    end

    @eligibility_report = PositionEligibilityService.new.check_eligibility(@teammate, @position)
    load_requirement_lists
  end

  private

  def set_positions
    @positions = Position.for_company(organization).ordered
  end

  def set_position
    @position = Position.find_by_param(params[:id])
  end

  def set_teammate
    teammate_id = params[:teammate_id].presence || current_company_teammate&.id
    @teammate = CompanyTeammate.find(teammate_id)
  end

  def set_selectable_teammates
    @selectable_teammates = selectable_teammates
  end

  def load_requirement_lists
    @required_assignments = @position.required_assignments.includes(:assignment).map(&:assignment)
    @unique_assignments = unique_to_you_assignments(@teammate, @position)

    @required_abilities = @required_assignments.flat_map do |assignment|
      assignment.assignment_abilities.includes(:ability).map(&:ability)
    end.uniq

    @unique_abilities = @unique_assignments.flat_map do |assignment|
      assignment.assignment_abilities.includes(:ability).map(&:ability)
    end.uniq

    position_company = @position.company
    @company_aspirations = Aspiration.for_company(position_company).ordered
    # Get aspirations for the title's department (if any)
    @title_department_aspirations = @position.title.department ? 
      Aspiration.for_department(@position.title.department).ordered : 
      Aspiration.none
  end

  def selectable_teammates
    return [] unless current_person

    teammates = []
    teammates << current_company_teammate if current_company_teammate

    if CompanyTeammate.can_manage_employment_in_hierarchy?(current_person, organization)
      teammates.concat(
        CompanyTeammate.for_organization_hierarchy(organization)
                .where(last_terminated_at: nil)
                .includes(:person)
      )
    else
      reports = EmployeeHierarchyQuery.new(person: current_person, organization: organization).call
      report_person_ids = reports.map { |report| report[:person_id] }
      org_ids = organization.company? ? organization.self_and_descendants.map(&:id) : [organization.id]

      teammates.concat(
        CompanyTeammate.where(organization_id: org_ids, person_id: report_person_ids, last_terminated_at: nil)
                .includes(:person)
      )
    end

    teammates.compact.uniq { |teammate| teammate.id }.sort_by { |teammate| teammate.person.display_name }
  end

  def teammate_allowed?(teammate)
    return false unless teammate
    return true if current_company_teammate && teammate.id == current_company_teammate.id

    selectable_teammates.any? { |allowed| allowed.id == teammate.id }
  end

  def unique_to_you_assignments(teammate, position)
    return [] unless teammate && position

    required_assignment_ids = position.required_assignments.pluck(:assignment_id)
    teammate.assignment_tenures.active
            .where.not(assignment_id: required_assignment_ids)
            .includes(:assignment)
            .map(&:assignment)
            .uniq
  end
end
