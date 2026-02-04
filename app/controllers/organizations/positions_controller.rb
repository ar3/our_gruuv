class Organizations::PositionsController < ApplicationController
  before_action :set_organization
  before_action :set_position, only: [:show, :job_description, :edit, :update, :destroy, :manage_assignments, :update_assignments, :manage_eligibility, :update_eligibility]
  before_action :set_related_data, only: [:new, :edit, :create, :update]

  def index
    @positions = @organization.positions.includes(:title, :position_level)
    
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
      spotlight: params[:spotlight] || 'none'
    }
    
    @current_sort = @current_filters[:sort]
    @current_view = @current_filters[:view]
    @current_spotlight = @current_filters[:spotlight]
    
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
    redirect_to organization_positions_path(@organization, redirect_params)
  end

  def manage_assignments
    authorize @position, :manage_assignments?
    
    # Get position's company (root organization)
    company = @position.title.company.root_company
    
    # Load all assignments for the company
    @assignments = Assignment.where(company: company)
                            .includes(:department)
                            .ordered
    
    # Build nested structure: company > department > assignments
    @assignments_by_org = @assignments.group_by(&:department)
    
    # Get existing position assignments for pre-population
    @existing_position_assignments = @position.position_assignments.index_by(&:assignment_id)
    
    # Calculate totals for required and suggested assignments
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
    
    # Set return URL
    @return_url = organization_position_path(@organization, @position)
    @return_text = "Back to Position"
    
    render layout: 'overlay'
  end

  def update_assignments
    authorize @position, :manage_assignments?
    
    position_assignments_params = params[:position_assignments] || {}
    assignment_ids_to_keep = []
    errors = []
    
    # Process each assignment in params
    position_assignments_params.each do |assignment_id_str, assignment_data|
      assignment_id = assignment_id_str.to_i
      max_energy = assignment_data[:max_estimated_energy].present? ? assignment_data[:max_estimated_energy].to_i : 0
      
      # Skip if max_estimated_energy is 0 or not set
      next if max_energy <= 0
      
      assignment_ids_to_keep << assignment_id
      
      # Find or initialize PositionAssignment
      position_assignment = @position.position_assignments.find_or_initialize_by(assignment_id: assignment_id)
      
      # Update attributes
      min_energy = assignment_data[:min_estimated_energy].present? ? assignment_data[:min_estimated_energy].to_i : nil
      
      position_assignment.min_estimated_energy = min_energy
      position_assignment.max_estimated_energy = max_energy
      position_assignment.assignment_type = assignment_data[:assignment_type] || 'required'
      
      unless position_assignment.save
        errors << "Failed to save assignment #{assignment_id}: #{position_assignment.errors.full_messages.join(', ')}"
      end
    end
    
    # Destroy position assignments that are no longer in params or have max_energy = 0
    assignments_to_destroy = @position.position_assignments.where.not(assignment_id: assignment_ids_to_keep)
    assignments_to_destroy.destroy_all
    
    if errors.any?
      redirect_to manage_assignments_organization_position_path(@organization, @position), alert: "Some assignments could not be saved: #{errors.join('; ')}"
    else
      redirect_to manage_assignments_organization_position_path(@organization, @position), notice: 'Assignments updated successfully.'
    end
  end

  def manage_eligibility
    authorize @position, :manage_eligibility?
    
    # Parse existing JSONB for form pre-population
    @eligibility_data = @position.eligibility_requirements_explicit || {}
    
    # Calculate minimum mileage from required assignments
    @minimum_mileage_from_assignments = calculate_minimum_mileage_from_assignments
    
    render layout: determine_layout
  end

  def update_eligibility
    authorize @position, :manage_eligibility?
    
    eligibility_params = params[:eligibility_requirements]&.permit! || {}
    new_eligibility_data = {}
    
    # Build JSONB hash, only including sections with at least one field filled
    if eligibility_params[:mileage_requirements].present?
      mileage = eligibility_params[:mileage_requirements]
      if mileage[:minimum_mileage_points].present?
        new_eligibility_data['mileage_requirements'] = {
          'minimum_mileage_points' => mileage[:minimum_mileage_points].to_i
        }
      end
    end
    
    if eligibility_params[:position_check_in_requirements].present?
      pos_check = eligibility_params[:position_check_in_requirements]
      if pos_check[:minimum_rating].present? || pos_check[:minimum_months_at_or_above_rating_criteria].present?
        pos_data = {}
        pos_data['minimum_rating'] = pos_check[:minimum_rating].to_i if pos_check[:minimum_rating].present?
        pos_data['minimum_months_at_or_above_rating_criteria'] = pos_check[:minimum_months_at_or_above_rating_criteria].to_i if pos_check[:minimum_months_at_or_above_rating_criteria].present?
        new_eligibility_data['position_check_in_requirements'] = pos_data if pos_data.any?
      end
    end
    
    if eligibility_params[:required_assignment_check_in_requirements].present?
      req_ass = eligibility_params[:required_assignment_check_in_requirements]
      if req_ass[:minimum_rating].present? || req_ass[:minimum_months_at_or_above_rating_criteria].present? || req_ass[:minimum_percentage_of_assignments].present?
        req_data = {}
        req_data['minimum_rating'] = req_ass[:minimum_rating] if req_ass[:minimum_rating].present?
        req_data['minimum_months_at_or_above_rating_criteria'] = req_ass[:minimum_months_at_or_above_rating_criteria].to_i if req_ass[:minimum_months_at_or_above_rating_criteria].present?
        req_data['minimum_percentage_of_assignments'] = req_ass[:minimum_percentage_of_assignments].to_f if req_ass[:minimum_percentage_of_assignments].present?
        new_eligibility_data['required_assignment_check_in_requirements'] = req_data if req_data.any?
      end
    end
    
    if eligibility_params[:unique_to_you_assignment_check_in_requirements].present?
      unique_ass = eligibility_params[:unique_to_you_assignment_check_in_requirements]
      if unique_ass[:minimum_rating].present? || unique_ass[:minimum_months_at_or_above_rating_criteria].present? || unique_ass[:minimum_percentage_of_assignments].present?
        unique_data = {}
        unique_data['minimum_rating'] = unique_ass[:minimum_rating] if unique_ass[:minimum_rating].present?
        unique_data['minimum_months_at_or_above_rating_criteria'] = unique_ass[:minimum_months_at_or_above_rating_criteria].to_i if unique_ass[:minimum_months_at_or_above_rating_criteria].present?
        unique_data['minimum_percentage_of_assignments'] = unique_ass[:minimum_percentage_of_assignments].to_f if unique_ass[:minimum_percentage_of_assignments].present?
        new_eligibility_data['unique_to_you_assignment_check_in_requirements'] = unique_data if unique_data.any?
      end
    end
    
    if eligibility_params[:company_aspirational_values_check_in_requirements].present?
      company_asp = eligibility_params[:company_aspirational_values_check_in_requirements]
      if company_asp[:minimum_rating].present? || company_asp[:minimum_months_at_or_above_rating_criteria].present? || company_asp[:minimum_percentage_of_aspirational_values].present?
        company_data = {}
        company_data['minimum_rating'] = company_asp[:minimum_rating] if company_asp[:minimum_rating].present?
        company_data['minimum_months_at_or_above_rating_criteria'] = company_asp[:minimum_months_at_or_above_rating_criteria].to_i if company_asp[:minimum_months_at_or_above_rating_criteria].present?
        company_data['minimum_percentage_of_aspirational_values'] = company_asp[:minimum_percentage_of_aspirational_values].to_f if company_asp[:minimum_percentage_of_aspirational_values].present?
        new_eligibility_data['company_aspirational_values_check_in_requirements'] = company_data if company_data.any?
      end
    end
    
    if eligibility_params[:title_department_aspirational_values_check_in_requirements].present?
      title_asp = eligibility_params[:title_department_aspirational_values_check_in_requirements]
      if title_asp[:minimum_rating].present? || title_asp[:minimum_months_at_or_above_rating_criteria].present? || title_asp[:minimum_percentage_of_aspirational_values].present?
        title_data = {}
        title_data['minimum_rating'] = title_asp[:minimum_rating] if title_asp[:minimum_rating].present?
        title_data['minimum_months_at_or_above_rating_criteria'] = title_asp[:minimum_months_at_or_above_rating_criteria].to_i if title_asp[:minimum_months_at_or_above_rating_criteria].present?
        title_data['minimum_percentage_of_aspirational_values'] = title_asp[:minimum_percentage_of_aspirational_values].to_f if title_asp[:minimum_percentage_of_aspirational_values].present?
        new_eligibility_data['title_department_aspirational_values_check_in_requirements'] = title_data if title_data.any?
      end
    end
    
    # Validate numeric ranges
    errors = []
    new_eligibility_data.each do |key, value|
      if value.is_a?(Hash)
        if value['minimum_months_at_or_above_rating_criteria'].present? && value['minimum_months_at_or_above_rating_criteria'] < 0
          errors << "#{key.humanize}: Minimum months must be >= 0"
        end
        if value['minimum_percentage_of_assignments'].present? && (value['minimum_percentage_of_assignments'] < 0 || value['minimum_percentage_of_assignments'] > 100)
          errors << "#{key.humanize}: Minimum percentage must be between 0 and 100"
        end
        if value['minimum_percentage_of_aspirational_values'].present? && (value['minimum_percentage_of_aspirational_values'] < 0 || value['minimum_percentage_of_aspirational_values'] > 100)
          errors << "#{key.humanize}: Minimum percentage must be between 0 and 100"
        end
        if value['minimum_rating'].present? && key == 'position_check_in_requirements'
          rating = value['minimum_rating'].to_i
          unless (-3..3).include?(rating)
            errors << "Position check-in minimum rating must be between -3 and 3"
          end
        end
        if value['minimum_mileage_points'].present? && value['minimum_mileage_points'] < 0
          errors << "Minimum mileage points must be >= 0"
        end
      end
    end
    
    # Validate minimum mileage against required assignments
    if new_eligibility_data['mileage_requirements'].present? && new_eligibility_data['mileage_requirements']['minimum_mileage_points'].present?
      minimum_mileage_from_assignments = calculate_minimum_mileage_from_assignments
      entered_mileage = new_eligibility_data['mileage_requirements']['minimum_mileage_points'].to_i
      if entered_mileage < minimum_mileage_from_assignments
        errors << "Minimum mileage points (#{entered_mileage}) cannot be lower than the total from required assignments (#{minimum_mileage_from_assignments})"
      end
    end
    
    if errors.any?
      # Convert params to string-keyed hash for form re-population
      @eligibility_data = eligibility_params.to_h.deep_stringify_keys
      @minimum_mileage_from_assignments = calculate_minimum_mileage_from_assignments
      flash[:alert] = "Validation errors: #{errors.join('; ')}"
      render :manage_eligibility, status: :unprocessable_entity, layout: determine_layout
    else
      @position.update!(eligibility_requirements_explicit: new_eligibility_data)
      redirect_to organization_position_path(@organization, @position), notice: 'Eligibility requirements updated successfully.'
    end
  end

  private

  def set_organization
    @organization = Organization.find(params[:organization_id])
  end

  def set_position
    @position = @organization.positions.find(params[:id])
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
    
    @assignments = @organization.assignments.ordered
  end

  def position_params
    params.require(:position).permit(:title_id, :position_level_id, :external_title, :position_summary, :eligibility_requirements_summary, :version_type)
  end

  def calculate_minimum_mileage_from_assignments
    mileage_service = MilestoneMileageService.new
    total_points = 0
    
    @position.required_assignments.includes(assignment: :assignment_abilities).each do |position_assignment|
      position_assignment.assignment.assignment_abilities.each do |assignment_ability|
        total_points += mileage_service.milestone_points(assignment_ability.milestone_level)
      end
    end
    
    total_points
  end
end
