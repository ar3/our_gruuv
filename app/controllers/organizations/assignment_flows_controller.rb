# frozen_string_literal: true

class Organizations::AssignmentFlowsController < Organizations::OrganizationNamespaceBaseController
  before_action :authenticate_person!
  before_action :set_assignment_flow, only: [:show, :edit, :update, :destroy]

  after_action :verify_authorized, except: :index
  after_action :verify_policy_scoped, only: :index

  def index
    authorize company, :view_assignment_flows?
    @assignment_flows = policy_scope(AssignmentFlow).where(company: company).order(:name)
    render layout: determine_layout
  end

  def show
    authorize @assignment_flow
    @ordered_memberships = @assignment_flow.ordered_memberships.includes(assignment: [:department], added_by: :person)
    # Build row attributes for group name column: adjacent rows with same group_name get one cell with rowspan
    @group_name_row_attrs = []
    run_start = 0
    while run_start < @ordered_memberships.length
      membership = @ordered_memberships[run_start]
      group_name = membership.group_name.presence
      run_end = run_start
      run_end += 1 while run_end < @ordered_memberships.length && (@ordered_memberships[run_end].group_name.presence == group_name)
      rowspan = run_end - run_start
      (run_start...run_end).each_with_index do |r, i|
        @group_name_row_attrs[r] = i == 0 ? { first_of_run: true, rowspan: rowspan, group_name: group_name } : { first_of_run: false }
      end
      run_start = run_end
    end
    render layout: determine_layout
  end

  def new
    @assignment_flow = company.assignment_flows.build
    authorize @assignment_flow
    render layout: determine_layout
  end

  def create
    @assignment_flow = company.assignment_flows.build(assignment_flow_params)
    @assignment_flow.created_by = current_company_teammate
    @assignment_flow.updated_by = current_company_teammate
    authorize @assignment_flow

    if @assignment_flow.save
      redirect_to edit_organization_assignment_flow_path(@organization, @assignment_flow),
                  notice: 'Assignment flow was successfully created. Add assignments and set their order below.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @assignment_flow
    assignments = policy_scope(Assignment).where(company: company).includes(:department).order(:title)
    # Group by department, same order as assignments index: nil first, then by department display_name
    grouped = assignments.to_a.group_by(&:department)
    @assignments_by_department = grouped.sort_by { |dept, _| dept ? [1, dept.display_name] : [0, ''] }.to_h
    memberships_by_assignment = @assignment_flow.assignment_flow_memberships.index_by(&:assignment_id)
    @placement_by_assignment_id = memberships_by_assignment.transform_values(&:placement)
    @group_name_by_assignment_id = memberships_by_assignment.transform_values { |m| m.group_name.presence }
    render layout: determine_layout
  end

  def update
    authorize @assignment_flow
    @assignment_flow.assign_attributes(assignment_flow_params)
    @assignment_flow.updated_by = current_company_teammate

    if @assignment_flow.save
      AssignmentFlow.transaction do
        @assignment_flow.assignment_flow_memberships.destroy_all
        (params[:placements] || {}).each do |assignment_id_str, placement_str|
          next if placement_str.blank?
          placement = placement_str.to_i
          next if placement < 0
          assignment = company.assignments.find_by(id: assignment_id_str)
          next unless assignment
          group_name = params[:group_names]&.dig(assignment_id_str)&.presence
          @assignment_flow.assignment_flow_memberships.create!(
            assignment: assignment,
            placement: placement,
            added_by: current_company_teammate,
            group_name: group_name
          )
        end
      end
      redirect_to organization_assignment_flow_path(@organization, @assignment_flow), notice: 'Assignment flow was successfully updated.'
    else
      assignments = policy_scope(Assignment).where(company: company).includes(:department).order(:title)
      grouped = assignments.to_a.group_by(&:department)
      @assignments_by_department = grouped.sort_by { |dept, _| dept ? [1, dept.display_name] : [0, ''] }.to_h
      memberships_by_assignment = @assignment_flow.assignment_flow_memberships.index_by(&:assignment_id)
      @placement_by_assignment_id = memberships_by_assignment.transform_values(&:placement)
      @group_name_by_assignment_id = memberships_by_assignment.transform_values { |m| m.group_name.presence }
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @assignment_flow
    @assignment_flow.destroy
    redirect_to organization_assignment_flows_path(@organization), notice: 'Assignment flow was successfully deleted.'
  end

  private

  def set_assignment_flow
    @assignment_flow = company.assignment_flows.find(params[:id])
  end

  def assignment_flow_params
    params.require(:assignment_flow).permit(:name)
  end
end
