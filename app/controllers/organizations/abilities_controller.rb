class Organizations::AbilitiesController < Organizations::OrganizationNamespaceBaseController
  before_action :set_ability, only: [:show, :edit, :update, :destroy]
  before_action :authenticate_person!

  after_action :verify_authorized, except: :index
  after_action :verify_policy_scoped, only: :index

  def index
    @abilities = policy_scope(Ability).for_organization(@organization).recent
  end

  def show
    authorize @ability
  end

  def new
    @ability = @organization.abilities.build
    authorize @ability
  end

  def create
    @ability = @organization.abilities.build(ability_params)
    @ability.created_by = current_person
    @ability.updated_by = current_person
    
    authorize @ability

    if @ability.save
      redirect_to organization_ability_path(@organization, @ability), notice: 'Ability was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @ability
  end

  def update
    authorize @ability
    
    @ability.updated_by = current_person
    
    if @ability.update(ability_params)
      redirect_to organization_ability_path(@organization, @ability), notice: 'Ability was successfully updated.'
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

  def ability_params
    params.require(:ability).permit(:name, :description, :version)
  end
end
