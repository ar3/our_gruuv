class Organizations::AbilitiesController < Organizations::OrganizationNamespaceBaseController
  before_action :authenticate_person!
  before_action :set_ability, only: [:show, :edit, :update, :destroy]

  after_action :verify_authorized, except: :index
  after_action :verify_policy_scoped, only: :index

  def index
    @abilities = policy_scope(Ability).for_organization(@organization).recent
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

  private

  def set_ability
    @ability = @organization.abilities.find(params[:id])
  end
end
