class Organizations::PromptTemplatesController < Organizations::OrganizationNamespaceBaseController
  before_action :authenticate_person!
  before_action :set_prompt_template, only: [:edit, :update, :destroy]

  after_action :verify_authorized
  after_action :verify_policy_scoped, only: :index

  def index
    authorize company, :view_prompt_templates?
    @prompt_templates = policy_scope(PromptTemplate).where(company: company)
    @prompt_templates = @prompt_templates.ordered
  end

  def new
    @prompt_template = PromptTemplate.new(company: company)
    authorize @prompt_template
  end

  def create
    @prompt_template = PromptTemplate.new(prompt_template_params)
    @prompt_template.company = company
    authorize @prompt_template

    if @prompt_template.save
      redirect_to organization_prompt_templates_path(@organization), 
                  notice: 'Prompt template was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @prompt_template
    @prompt_questions = @prompt_template.prompt_questions.ordered
  end

  def update
    authorize @prompt_template

    if @prompt_template.update(prompt_template_params)
      redirect_to organization_prompt_templates_path(@organization), 
                  notice: 'Prompt template was successfully updated.'
    else
      @prompt_questions = @prompt_template.prompt_questions.ordered
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @prompt_template
    @prompt_template.destroy
    redirect_to organization_prompt_templates_path(@organization), 
                notice: 'Prompt template was successfully deleted.'
  end

  private

  def set_prompt_template
    @prompt_template = PromptTemplate.find_by(id: params[:id], company: company)
    unless @prompt_template
      redirect_to organization_prompt_templates_path(@organization), 
                  alert: 'Prompt template not found.'
    end
  end

  def prompt_template_params
    params.require(:prompt_template).permit(:title, :description, :available_at, 
                                            :is_primary, :is_secondary, :is_tertiary)
  end
end



