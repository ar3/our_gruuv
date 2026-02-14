class Organizations::AbilitiesController < Organizations::OrganizationNamespaceBaseController
  before_action :authenticate_person!
  before_action :set_ability, only: [:show, :edit, :update, :destroy]

  after_action :verify_authorized
  after_action :verify_policy_scoped, only: :index

  def index
    authorize company, :view_abilities?
    @abilities = policy_scope(Ability).for_company(company).includes(:department)
    
    # Apply filters
    @abilities = @abilities.where("abilities.name ILIKE ?", "%#{params[:name]}%") if params[:name].present?
    
    # Filter by department
    if params[:department_id].present?
      if params[:department_id] == 'none'
        @abilities = @abilities.where(department_id: nil)
      else
        @abilities = @abilities.where(department_id: params[:department_id])
      end
    end
    
    if params[:milestone_status].present?
      milestone_statuses = Array(params[:milestone_status])
      if milestone_statuses.include?('with_milestones')
        @abilities = @abilities.joins(:teammate_milestones).distinct
      elsif milestone_statuses.include?('without_milestones')
        @abilities = @abilities.left_joins(:teammate_milestones).where(teammate_milestones: { id: nil })
      elsif milestone_statuses.include?('high_activity')
        @abilities = @abilities.joins(:teammate_milestones).group('abilities.id').having('COUNT(teammate_milestones.id) > 5')
      end
    end
    
    # Filter by major version (using SQL LIKE for efficiency)
    if params[:major_version].present?
      major_version = params[:major_version].to_i
      @abilities = @abilities.where("semantic_version LIKE ?", "#{major_version}.%")
    end
    
    # Apply sorting (default department_and_name for grouped-by-department style)
    case params[:sort]
    when 'name'
      @abilities = @abilities.order('abilities.name')
    when 'department_and_name'
      @abilities = @abilities.left_joins(:department).order(Arel.sql("COALESCE(departments.name, '')"), Arel.sql("abilities.name"))
    when 'milestones'
      @abilities = @abilities.left_joins(:teammate_milestones).group('abilities.id').order('COUNT(teammate_milestones.id) DESC')
    when 'milestones_desc'
      @abilities = @abilities.left_joins(:teammate_milestones).group('abilities.id').order('COUNT(teammate_milestones.id) ASC')
    when 'created_at'
      @abilities = @abilities.order(created_at: :desc)
    when 'created_at_asc'
      @abilities = @abilities.order(created_at: :asc)
    when 'version'
      @abilities = @abilities.order(:semantic_version)
    else
      # Default: sort by department then name (for grouped-by-department view)
      @abilities = @abilities.left_joins(:department).order(Arel.sql("COALESCE(departments.name, '')"), Arel.sql("abilities.name"))
    end
    
    # Apply direction if specified
    if params[:direction] == 'desc' && params[:sort] == 'name'
      @abilities = @abilities.order(Arel.sql("abilities.name DESC"))
    end
    
    # Group abilities by department (nil = "No Department"), sorted like assignments index
    abilities_array = @abilities.to_a
    grouped = abilities_array.group_by(&:department)
    @abilities_by_department = grouped.sort_by { |dept, _| dept ? [1, dept.display_name] : [0, ''] }.to_h
    @abilities_by_department.transform_values! { |list| list.sort_by(&:name) }
    @department_stats = {}
    @abilities_by_department.each do |dept, list|
      @department_stats[dept] = { abilities_count: list.size }
    end
    
    # Current filters, sort, view, spotlight for display (default spotlight: by_department)
    @current_spotlight = params[:spotlight].presence || 'by_department'
    @current_sort = params[:sort].presence || 'department_and_name'
    @current_view = params[:view].presence || 'table'
    @current_filters = {
      name: params[:name],
      department_id: params[:department_id],
      milestone_status: params[:milestone_status],
      major_version: params[:major_version],
      sort: @current_sort,
      direction: params[:direction],
      view: @current_view,
      spotlight: @current_spotlight
    }
    
    # Spotlight stats for by_department
    if @current_spotlight == 'by_department'
      @spotlight_stats = calculate_abilities_by_department_stats(abilities_array)
    end
  end

  def show
    authorize @ability
  end

  def new
    @ability = Ability.new(company: company)
    # Prefill default milestone descriptions for the form (not persisted until save)
    (1..5).each do |level|
      @ability.send("milestone_#{level}_description=", Ability.default_milestone_description(level))
    end
    @ability_decorator = AbilityDecorator.new(@ability)
    @form = AbilityForm.new(@ability)
    @form.current_person = current_person
    @departments = Department.for_company(company).active.ordered.sort_by(&:display_name)
    authorize @ability
  end

  def create
    # Always authorize first
    authorize Ability.new(company: company)
    
    # Reform handles validation and parameter extraction
    # Handle case where no ability parameters are provided
    ability_params = params[:ability] || {}
    
    @form = AbilityForm.new(Ability.new(company: company))
    @form.current_person = current_person
    @departments = Department.for_company(company).active.ordered.sort_by(&:display_name)
    
    # Set flag for empty form data validation
    @form.instance_variable_set(:@form_data_empty, ability_params.empty?)
    
    if @form.validate(ability_params) && @form.save
      redirect_to organization_ability_path(@organization, @form.model), 
                  notice: 'Ability was successfully created.'
    else
      @ability_decorator = AbilityDecorator.new(@form.model)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @ability_decorator = AbilityDecorator.new(@ability)
    # Prefill milestone descriptions when all five are blank (for display only; not persisted until save)
    if (1..5).all? { |level| @ability.send("milestone_#{level}_description").blank? }
      (1..5).each do |level|
        @ability.send("milestone_#{level}_description=", Ability.default_milestone_description(level))
      end
    end
    @form = AbilityForm.new(@ability)
    @form.current_person = current_person
    @departments = Department.for_company(company).active.ordered.sort_by(&:display_name)
    authorize @ability
  end

  def update
    # Always authorize first
    authorize @ability
    
    @ability_decorator = AbilityDecorator.new(@ability)
    @form = AbilityForm.new(@ability)
    @form.current_person = current_person
    @departments = Department.for_company(company).active.ordered.sort_by(&:display_name)
    
    # Reform handles validation and parameter extraction
    # Handle case where no ability parameters are provided
    ability_params = params[:ability] || {}
    
    # Set flag for empty form data validation
    @form.instance_variable_set(:@form_data_empty, ability_params.empty?)
    
    if @form.validate(ability_params) && @form.save
      redirect_to organization_ability_path(@organization, @form.model), 
                  notice: 'Ability was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @ability
    
    @ability.destroy
    redirect_to organization_abilities_path(@organization), notice: 'Ability was successfully deleted.'
  end

  def customize_view
    authorize @organization, :show?
    
    # Load current state from params
    @current_filters = {
      name: params[:name],
      category: params[:category],
      milestone_status: params[:milestone_status],
      major_version: params[:major_version],
      department_id: params[:department_id],
      sort: params[:sort] || 'department_and_name',
      direction: params[:direction] || 'asc',
      view: params[:view] || 'table',
      spotlight: params[:spotlight] || 'by_department'
    }
    
    @current_sort = @current_filters[:sort]
    @current_view = @current_filters[:view]
    @current_spotlight = @current_filters[:spotlight]
    @departments = Department.for_company(company).active.ordered.sort_by(&:display_name)
    
    # Preserve current params for return URL
    return_params = params.except(:controller, :action, :page).permit!.to_h
    @return_url = organization_abilities_path(@organization, return_params)
    @return_text = "Back to Abilities"
    
    render layout: 'overlay'
  end

  def update_view
    authorize @organization, :show?
    
    # Build redirect URL with all view customization params
    redirect_params = params.except(:controller, :action, :utf8, :_method, :commit).permit!.to_h
    redirect_to organization_abilities_path(@organization, redirect_params)
  end

  private

  def set_ability
    @ability = company.abilities.find(params[:id])
  end

  def calculate_abilities_by_department_stats(abilities)
    by_dept = abilities.group_by(&:department)
    stats = {}
    by_dept.each do |dept, list|
      key = dept&.id || :none
      stats[key] = {
        department: dept,
        display_name: dept ? dept.display_name : 'No Department',
        count: list.size
      }
    end
    {
      total_abilities: abilities.size,
      total_departments: by_dept.size,
      departments: stats
    }
  end
end
