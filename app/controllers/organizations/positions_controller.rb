class Organizations::PositionsController < ApplicationController
  before_action :set_organization
  before_action :set_position, only: [:show, :job_description, :edit, :update, :destroy, :archive, :execute_archive, :restore, :manage_assignments, :update_assignments, :manage_eligibility, :update_eligibility]
  before_action :load_positions_for_header_switcher, only: [:show]
  before_action :set_related_data, only: [:new, :edit, :create, :update]

  def index
    @current_show_archived = params[:show_archived].to_s == '1'
    scope = @organization.positions
    scope = scope.unarchived unless @current_show_archived
    @positions = scope.includes(:title, :position_level)
    
    # Apply filters
    @positions = @positions.where(title_id: params[:title]) if params[:title].present?
    @positions = @positions.where(position_level_id: params[:position_level]) if params[:position_level].present?
    
    # Filter by department
    if params[:department].present?
      @positions = @positions.joins(:title).where(titles: { department_id: params[:department] })
    end
    
    # Filter by major version (using SQL LIKE for efficiency)
    if params[:major_version].present?
      major_version = params[:major_version].to_i
      @positions = @positions.where("semantic_version LIKE ?", "#{major_version}.%")
    end
    
    # Apply sorting
    case params[:sort]
    when 'name'
      @positions = @positions.joins(:title).order('titles.external_title')
    when 'level'
      @positions = @positions.joins(:position_level).order('position_levels.level')
    when 'assignments'
      @positions = @positions.left_joins(:position_assignments).group('positions.id').order('COUNT(position_assignments.id) DESC')
    when 'created_at'
      @positions = @positions.order(created_at: :desc)
    when 'created_at_asc'
      @positions = @positions.order(created_at: :asc)
    else
      @positions = @positions.ordered
    end
    
    # Apply direction if specified
    if params[:direction] == 'desc'
      case params[:sort]
      when 'name'
        @positions = @positions.joins(:title).order('titles.external_title DESC')
      when 'level'
        @positions = @positions.joins(:position_level).order('position_levels.level DESC')
      end
    end
    
    # Load titles with department for grouping
    # Eager load positions with position_level to avoid N+1 queries
    @titles = @organization.titles
      .includes(
        :position_major_level,
        :department,
        positions: [:position_level]
      )
      .order(:external_title)
    # When not showing archived, filter out archived positions from each title’s list (view uses @current_show_archived to match)
    unless @current_show_archived
      @titles.each { |t| t.association(:positions).target = t.positions.to_a.reject(&:archived?) }
    end
    
    # Preload position assignment counts to avoid N+1 queries
    # Get all position IDs first
    position_ids = @titles.flat_map { |t| t.positions.map(&:id) }
    
    # Load all position assignments in one query and group by position_id
    # Only query if there are positions to avoid empty query
    position_assignments_by_position = if position_ids.any?
      PositionAssignment
        .where(position_id: position_ids)
        .group_by(&:position_id)
    else
      {}
    end
    
    # Attach counts to positions as instance variables to avoid method calls
    @titles.each do |title|
      title.positions.each do |position|
        pas = position_assignments_by_position[position.id] || []
        position.instance_variable_set(:@required_count, pas.count { |pa| pa.assignment_type == 'required' })
        position.instance_variable_set(:@suggested_count, pas.count { |pa| pa.assignment_type == 'suggested' })
      end
    end
    
    # Group titles by department for display
    @titles_by_department = @titles.group_by { |title| title.department }
    
    # Sort departments hierarchically by display_name (which includes full path)
    # This will naturally sort: Company, Company > Department A, Company > Department A > Department A.1, etc.
    @titles_by_department = @titles_by_department.sort_by do |department, _titles|
      # nil departments (no department) should come first, then sort by display_name
      department ? [1, department.display_name] : [0, '']
    end.to_h
    
    # Sort titles within each department alphanumerically
    @titles_by_department.each do |_department, titles|
      titles.sort_by! { |title| title.external_title }
    end
    
    # Pre-calculate counts for each department to avoid N+1 queries
    @department_stats = {}
    @titles_by_department.each do |department, titles|
      distinct_titles_count = titles.count
      total_positions_count = titles.sum { |t| t.positions.size }
      @department_stats[department] = {
        titles_count: distinct_titles_count,
        positions_count: total_positions_count
      }
    end
    
    render layout: determine_layout
  end

  def show
    # Load employees with this position if current user is a manager
    if current_company_teammate&.has_direct_reports?
      @employees_with_position = EmploymentTenure
        .active
        .where(position: @position, company: @position.company)
        .joins(company_teammate: :person)
        .includes(company_teammate: :person)
        .order('people.last_name, people.first_name')
    end
    @eligibility_requirements_sentences = helpers.eligibility_requirements_sentences_from_config(@position)
    @ability_milestone_requirements = helpers.ability_milestone_requirements_for_position(@position)
    set_eligibility_source_context_for_show
    @position_clarity_run = @position.latest_position_clarity_consultation
    @position_reliance_network = Assignments::PositionRelianceNetworkGraph.new(
      position: @position,
      organization: @organization
    )
    render layout: determine_layout
  end

  def job_description
    render layout: determine_layout
  end

  def new
    unless params[:title_id].present?
      redirect_to organization_positions_path(@organization), alert: 'Title is required to create a position.'
      return
    end
    
    @position = Position.new
    @position.title_id = params[:title_id]
    @title = Title.find(params[:title_id])
    
    # Ensure the title belongs to the company
    unless @title.company_id == @organization.id
      redirect_to organization_positions_path(@organization), alert: 'Invalid title for this organization.'
      return
    end
    
    # Pre-populate position levels based on the selected title
    @position_levels = @title.position_major_level.position_levels
    
    @position_decorator = PositionDecorator.new(@position)
    @form = PositionForm.new(@position)
    @form.current_person = current_person
    @form.instance_variable_set(:@form_data_empty, true)
    render layout: determine_layout
  end

  def create
    # Get title_id from params or from position_params
    title_id = params[:title_id] || position_params[:title_id]
    
    unless title_id.present?
      redirect_to organization_positions_path(@organization), alert: 'Title is required to create a position.'
      return
    end
    
    @position = Position.new
    @position.title_id = title_id
    @title = Title.find(title_id)
    
    # Ensure the title belongs to the company
    unless @title.company_id == @organization.id
      redirect_to organization_positions_path(@organization), alert: 'Invalid title for this organization.'
      return
    end
    
    authorize @position, :create?
    
    @position_decorator = PositionDecorator.new(@position)
    @form = PositionForm.new(@position)
    @form.current_person = current_person
    
    # Set flag for empty form data validation
    position_params_hash = position_params || {}
    @form.instance_variable_set(:@form_data_empty, position_params_hash.empty?)

    if @form.validate(position_params) && @form.save
      redirect_to organization_position_path(@organization, @position), notice: 'Position was successfully created.'
    else
      @position_levels = @title.position_major_level.position_levels
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @position_decorator = PositionDecorator.new(@position)
    @form = PositionForm.new(@position)
    @form.current_person = current_person
    render layout: determine_layout
  end

  def update
    authorize @position, :update?
    
    @position_decorator = PositionDecorator.new(@position)
    @form = PositionForm.new(@position)
    @form.current_person = current_person
    
    # Set flag for empty form data validation
    position_params_hash = position_params || {}
    @form.instance_variable_set(:@form_data_empty, position_params_hash.empty?)

    if @form.validate(position_params) && @form.save
      redirect_to organization_position_path(@organization, @position), notice: 'Position was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @position, :destroy?
    
    @position.destroy
    redirect_to organization_positions_path(@organization), notice: 'Position was successfully deleted.'
  end

  def position_levels
    if params[:title_id].present?
      title = Title.find(params[:title_id])
      @position_levels = title.position_major_level.position_levels
      render json: @position_levels.map { |level| { id: level.id, level: level.level, level_name: level.level_name } }
    else
      render json: []
    end
  end

  def customize_view
    authorize @organization, :show?
    set_related_data
    
    # Load current state from params
    @current_filters = {
      title: params[:title],
      position_level: params[:position_level],
      department: params[:department],
      major_version: params[:major_version],
      sort: params[:sort] || 'name',
      direction: params[:direction] || 'asc',
      view: params[:view] || 'table',
      spotlight: params[:spotlight] || 'none',
      show_archived: params[:show_archived].to_s == '1'
    }
    
    @current_sort = @current_filters[:sort]
    @current_view = @current_filters[:view]
    @current_spotlight = @current_filters[:spotlight]
    @current_show_archived = @current_filters[:show_archived]
    
    # Preserve current params for return URL
    return_params = params.except(:controller, :action, :page).permit!.to_h
    @return_url = organization_positions_path(@organization, return_params)
    @return_text = "Back to Positions"
    
    render layout: 'overlay'
  end

  def update_view
    authorize @organization, :show?
    
    # Build redirect URL with all view customization params
    redirect_params = params.except(:controller, :action, :utf8, :_method, :commit).permit!.to_h
    redirect_params[:show_archived] = params[:show_archived] if params[:show_archived].present?
    redirect_to organization_positions_path(@organization, redirect_params)
  end

  def archive
    authorize @position, :archive?
    @position_assignments = @position.position_assignments.includes(assignment: :company)
    @position_abilities = @position.position_abilities.includes(ability: :company)
    @active_employment_tenures = EmploymentTenure.where(position: @position).active
      .includes(company_teammate: :person)
    @archivable = @position.archivable?
    render layout: determine_layout
  end

  def execute_archive
    authorize @position, :archive?
    unless @position.archivable?
      redirect_to archive_organization_position_path(@organization, @position),
                  alert: 'Cannot archive: remove all position assignments, ability requirements, and active employment first.'
      return
    end
    @position.archive!
    redirect_to organization_position_path(@organization, @position), notice: 'Position was successfully archived.'
  end

  def restore
    authorize @position, :restore?
    @position.restore!
    redirect_to organization_position_path(@organization, @position), notice: 'Position was successfully restored.'
  end

  def manage_assignments
    authorize @position, :manage_assignments?

    company = @position.title.company.root_company

    @assignments = Assignment.unarchived
                            .where(company: company)
                            .includes(:department)
                            .to_a
                            .sort_by { |a| [(a.department&.display_name || "Company-wide").downcase, a.title.to_s.downcase] }

    @existing_position_assignments = @position.position_assignments.index_by(&:assignment_id)
    associated_ids = @existing_position_assignments.keys

    @associated_assignments = @assignments.select { |a| associated_ids.include?(a.id) }
    @available_assignments = @assignments.reject { |a| associated_ids.include?(a.id) }

    required_pas = @position.position_assignments.required
    suggested_pas = @position.position_assignments.suggested

    @required_totals = {
      min: required_pas.sum { |pa| pa.min_estimated_energy || 0 },
      max: required_pas.sum { |pa| pa.max_estimated_energy || 0 },
      anticipated: required_pas.sum { |pa| pa.anticipated_energy_percentage || 0 }
    }

    @suggested_totals = {
      min: suggested_pas.sum { |pa| pa.min_estimated_energy || 0 },
      max: suggested_pas.sum { |pa| pa.max_estimated_energy || 0 },
      anticipated: suggested_pas.sum { |pa| pa.anticipated_energy_percentage || 0 }
    }

    # Sibling positions in the same title (different position_level), used by the
    # "Copy Position Assignments" card to compare and copy configurations.
    @sibling_positions = @position.title.positions
                                  .unarchived
                                  .where.not(id: @position.id)
                                  .includes(:position_level, position_assignments: :assignment)
                                  .joins(:position_level)
                                  .order('position_levels.level')
    @assignment_diffs = @sibling_positions.index_with do |sp|
      PositionAssignments::Diff.call(source: sp, destination: @position)
    end

    @return_url = organization_position_path(@organization, @position)
    @return_text = "Back to Position"

    render layout: 'overlay'
  end

  def update_assignments
    authorize @position, :manage_assignments?

    position_assignments_params = params[:position_assignments] || {}
    assignment_ids_to_keep = []
    errors = []

    position_assignments_params.each do |assignment_id_str, assignment_data|
      assignment_id = assignment_id_str.to_i
      assignment_type = resolve_assignment_association_type(assignment_data)
      next unless assignment_type

      min_energy, max_energy = resolve_assignment_energy_values(assignment_data, assignment_type)
      next if max_energy <= 0

      assignment_ids_to_keep << assignment_id

      position_assignment = @position.position_assignments.find_or_initialize_by(assignment_id: assignment_id)
      position_assignment.min_estimated_energy = min_energy
      position_assignment.max_estimated_energy = max_energy
      position_assignment.assignment_type = assignment_type

      unless position_assignment.save
        errors << "Failed to save assignment #{assignment_id}: #{position_assignment.errors.full_messages.join(', ')}"
      end
    end

    @position.position_assignments.where.not(assignment_id: assignment_ids_to_keep).destroy_all

    if errors.any?
      redirect_to manage_assignments_organization_position_path(@organization, @position), alert: "Some assignments could not be saved: #{errors.join('; ')}"
      return
    end

    @position.reload
    @position.record_version_for_assignment_changes!

    if params[:copy_action].present?
      perform_copy_action!(params[:copy_action])
    else
      redirect_to manage_assignments_organization_position_path(@organization, @position), notice: 'Assignments updated successfully.'
    end
  end

  def manage_eligibility
    authorize @position, :manage_eligibility?

    resolved = PositionEligibilityResolver.resolve(@position)
    @eligibility_data = resolved.record.to_eligibility_service_hash
    @eligibility_config_source = resolved.source
    @minimum_mileage_from_assignments = calculate_minimum_mileage_from_assignments

    render layout: determine_layout
  end

  def update_eligibility
    authorize @position, :manage_eligibility?

    eligibility_params = params[:eligibility_requirements]&.permit! || {}
    new_eligibility_data = EligibilityRequirements::BuildEligibilityHash.call(eligibility_params)
    min_floor = calculate_minimum_mileage_from_assignments
    errors = EligibilityRequirements::ValidateEligibilityHash.call(new_eligibility_data, minimum_mileage_floor: min_floor)

    if errors.any?
      @eligibility_data = eligibility_params.to_h.deep_stringify_keys
      @minimum_mileage_from_assignments = min_floor
      resolved = PositionEligibilityResolver.resolve(@position)
      @eligibility_config_source = resolved.source
      flash[:alert] = "Validation errors: #{errors.join('; ')}"
      render :manage_eligibility, status: :unprocessable_entity, layout: determine_layout
    else
      requirement = EligibilityRequirements::FindOrCreate.call!(new_eligibility_data)
      @position.update!(position_eligibility_requirement_id: requirement.id)
      redirect_to organization_position_path(@organization, @position), notice: 'Eligibility requirements updated successfully.'
    end
  end

  private

  def load_positions_for_header_switcher
    @positions_by_department = positions_by_department_for_switcher(@organization)
  end

  def positions_by_department_for_switcher(org)
    positions = Position.for_company(org).unarchived
      .includes(:position_level, title: [:department, :position_major_level])
      .left_joins(title: :department)
      .order(
        Arel.sql('CASE WHEN titles.department_id IS NULL THEN 0 ELSE 1 END'),
        'departments.name',
        'titles.external_title',
        'position_levels.level'
      )

    groups = positions.group_by { |p| p.title.department&.display_name || 'Company-wide' }
    result = {}
    result['Company-wide'] = groups['Company-wide'] if groups['Company-wide'].present?
    (groups.keys - ['Company-wide']).sort.each do |label|
      result[label] = groups[label]
    end
    result
  end

  def set_organization
    @organization = Organization.find(params[:organization_id])
  end

  def set_position
    @position = @organization.positions.includes(
      :position_eligibility_requirement,
      position_abilities: :ability,
      position_assignments: { assignment: { assignment_abilities: :ability } }
    ).find(params[:id])
  end

  def set_related_data
    @titles = Title.joins(:company, :position_major_level)
                   .where(organizations: { id: @organization.id })
                   .order('position_major_levels.major_level, titles.external_title')
    
    # Set position levels based on current position's title, or from title_id param
    if @position&.title
      @position_levels = @position.title.position_major_level.position_levels
      @title = @position.title
    elsif params[:title_id].present?
      @title = Title.find_by(id: params[:title_id], company: @organization)
      @position_levels = @title&.position_major_level&.position_levels || []
    else
      @position_levels = []
    end
    
    @assignments = @organization.assignments.unarchived.ordered
  end

  def set_eligibility_source_context_for_show
    resolved = PositionEligibilityResolver.resolve(@position)
    minor = @position.position_level.eligibility_minor_slot

    case resolved.source
    when :position
      @eligibility_source_caption_text = "These requirements are currently coming from position-specific settings. Click Manage Eligibility in the Actions bar to edit."
      @eligibility_source_link_text = nil
      @eligibility_source_link_path = nil
    when :department
      department = @position.title.department
      @eligibility_source_caption_text = "These requirements are currently coming from department defaults (minor #{minor})."
      @eligibility_source_link_text = "View department eligibility defaults"
      @eligibility_source_link_path = organization_department_position_eligibility_defaults_path(@organization, department)
    else
      @eligibility_source_caption_text = "These requirements are currently coming from organization defaults (minor #{minor})."
      @eligibility_source_link_text = "View organization eligibility defaults"
      @eligibility_source_link_path = organization_position_eligibility_defaults_path(@organization)
    end
  end

  def position_params
    params.require(:position).permit(:title_id, :position_level_id, :external_title, :position_summary, :version_type)
  end

  # Handles a "copy_action" param of the form "to:<sibling_id>" or "from:<sibling_id>"
  # submitted from the Copy Position Assignments card on manage_assignments.
  # Saves on the page have already happened by the time this is called.
  def perform_copy_action!(raw_action)
    direction, sibling_id_str = raw_action.to_s.split(':', 2)
    sibling_id = sibling_id_str.to_i

    unless %w[to from].include?(direction) && sibling_id.positive?
      redirect_to manage_assignments_organization_position_path(@organization, @position),
                  alert: 'Invalid copy action.'
      return
    end

    sibling = @position.title.positions.unarchived.where.not(id: @position.id).find_by(id: sibling_id)
    unless sibling
      redirect_to manage_assignments_organization_position_path(@organization, @position),
                  alert: 'Could not find a sibling position with that id for this title.'
      return
    end

    if direction == 'to'
      source = @position
      destination = sibling
      change_context = "Copied position assignments from #{@position.display_name} via manage_assignments page"
    else
      source = sibling
      destination = @position
      change_context = "Copied position assignments from #{sibling.display_name} via manage_assignments page"
    end

    PositionAssignments::CopyConfiguration.call(
      source: source,
      destination: destination,
      change_context: change_context
    )

    notice = "Saved current configuration and copied assignments from #{source.display_name} into #{destination.display_name}."
    redirect_to manage_assignments_organization_position_path(@organization, @position), notice: notice
  rescue ActiveRecord::RecordInvalid => e
    redirect_to manage_assignments_organization_position_path(@organization, @position),
                alert: "Copy failed: #{e.record.errors.full_messages.join('; ')}"
  rescue ArgumentError => e
    redirect_to manage_assignments_organization_position_path(@organization, @position),
                alert: "Copy failed: #{e.message}"
  end

  def calculate_minimum_mileage_from_assignments
    mileage_service = MilestoneMileageService.new
    total_points = 0

    @position.required_assignments.includes(assignment: :assignment_abilities).each do |position_assignment|
      position_assignment.assignment.assignment_abilities.each do |assignment_ability|
        total_points += mileage_service.milestone_points(assignment_ability.milestone_level)
      end
    end

    @position.position_abilities.each do |position_ability|
      total_points += mileage_service.milestone_points(position_ability.milestone_level)
    end

    total_points
  end

  # Returns 'required'/'suggested', or nil when the row should not be associated.
  # Legacy payloads without assignment_type still associate when max_energy > 0.
  def resolve_assignment_association_type(assignment_data)
    raw_type = assignment_data[:assignment_type].to_s
    return raw_type if %w[required suggested].include?(raw_type)
    return nil if raw_type.present?

    max_energy = assignment_data[:max_estimated_energy].present? ? assignment_data[:max_estimated_energy].to_i : 0
    max_energy > 0 ? 'required' : nil
  end

  def resolve_assignment_energy_values(assignment_data, assignment_type)
    defaults = assignment_type == 'suggested' ? [0, 10] : [5, 15]

    if assignment_data[:max_estimated_energy].present?
      max_energy = assignment_data[:max_estimated_energy].to_i
      min_energy = assignment_data[:min_estimated_energy].present? ? assignment_data[:min_estimated_energy].to_i : nil
      [min_energy, max_energy]
    else
      defaults
    end
  end

end
