class Organizations::AbilitiesController < Organizations::OrganizationNamespaceBaseController
  before_action :authenticate_person!
  before_action :set_ability, only: [:show, :edit, :update, :destroy]

  after_action :verify_authorized
  after_action :verify_policy_scoped, only: :index

  def index
    authorize company, :view_abilities?
    @abilities = policy_scope(Ability).for_organization(@organization)
    
    # Apply filters
    @abilities = @abilities.where("name ILIKE ?", "%#{params[:name]}%") if params[:name].present?
    
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
    
    # Apply sorting
    case params[:sort]
    when 'name'
      @abilities = @abilities.order(:name)
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
      @abilities = @abilities.recent
    end
    
    # Apply direction if specified
    if params[:direction] == 'desc' && params[:sort] == 'name'
      @abilities = @abilities.order(name: :desc)
    end
  end

  def show
    authorize @ability
  end

  def new
    @ability = Ability.new(organization: @organization)
    @ability_decorator = AbilityDecorator.new(@ability)
    @form = AbilityForm.new(@ability)
    @form.current_person = current_person
    authorize @ability
  end

  def create
    # Always authorize first
    authorize Ability.new(organization: @organization)
    
    # Reform handles validation and parameter extraction
    # Handle case where no ability parameters are provided
    ability_params = params[:ability] || {}
    
    @form = AbilityForm.new(Ability.new(organization: @organization))
    @form.current_person = current_person
    
    # Set flag for empty form data validation
    @form.instance_variable_set(:@form_data_empty, ability_params.empty?)
    
    if @form.validate(ability_params) && @form.save
      redirect_to organization_ability_path(@form.model.organization, @form.model), 
                  notice: 'Ability was successfully created.'
    else
      @ability_decorator = AbilityDecorator.new(@form.model)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @ability_decorator = AbilityDecorator.new(@ability)
    @form = AbilityForm.new(@ability)
    @form.current_person = current_person
    authorize @ability
  end

  def update
    # Always authorize first
    authorize @ability
    
    @ability_decorator = AbilityDecorator.new(@ability)
    @form = AbilityForm.new(@ability)
    @form.current_person = current_person
    
    # Reform handles validation and parameter extraction
    # Handle case where no ability parameters are provided
    ability_params = params[:ability] || {}
    
    # Set flag for empty form data validation
    @form.instance_variable_set(:@form_data_empty, ability_params.empty?)
    
    if @form.validate(ability_params) && @form.save
      redirect_to organization_ability_path(@form.model.organization, @form.model), 
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
      sort: params[:sort] || 'name',
      direction: params[:direction] || 'asc',
      view: params[:view] || 'table',
      spotlight: params[:spotlight] || 'ability_overview'
    }
    
    @current_sort = @current_filters[:sort]
    @current_view = @current_filters[:view]
    @current_spotlight = @current_filters[:spotlight]
    
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
    @ability = @organization.abilities.find(params[:id])
  end
end
