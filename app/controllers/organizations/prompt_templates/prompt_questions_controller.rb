class Organizations::PromptTemplates::PromptQuestionsController < Organizations::OrganizationNamespaceBaseController
  before_action :authenticate_person!
  before_action :set_prompt_template
  before_action :set_prompt_question, only: [:edit, :update, :destroy, :archive, :unarchive]

  after_action :verify_authorized

  def new
    @prompt_question = @prompt_template.prompt_questions.build
    authorize @prompt_question
    @return_url = params[:return_url] || edit_organization_prompt_template_path(@organization, @prompt_template)
    @return_text = params[:return_text] || 'Back to Template'
    render layout: 'overlay'
  end

  def create
    @prompt_question = @prompt_template.prompt_questions.build
    authorize @prompt_question

    service = PromptQuestionSaveService.new(@prompt_question)
    result = service.call(prompt_question_params)

    if result[:success]
      # Save the template to ensure it's persisted
      @prompt_template.save if @prompt_template.changed?
      
      # Redirect to manage question page (edit) to show paper trail
      redirect_to edit_organization_prompt_template_prompt_question_path(
        @organization, 
        @prompt_template, 
        result[:prompt_question],
        return_url: params[:return_url] || edit_organization_prompt_template_path(@organization, @prompt_template),
        return_text: params[:return_text] || 'Back to Template'
      ), notice: 'Question was successfully created.'
    else
      @prompt_question.errors.merge!(result[:errors]) if result[:errors]
      @return_url = params[:return_url] || edit_organization_prompt_template_path(@organization, @prompt_template)
      @return_text = params[:return_text] || 'Back to Template'
      render :new, layout: 'overlay', status: :unprocessable_entity
    end
  end

  def edit
    authorize @prompt_question
    @return_url = params[:return_url] || edit_organization_prompt_template_path(@organization, @prompt_template)
    @return_text = params[:return_text] || 'Back to Template'
    @versions = @prompt_question.versions.order(created_at: :desc)
    render layout: 'overlay'
  end

  def update
    authorize @prompt_question

    if @prompt_question.archived?
      redirect_to edit_organization_prompt_template_path(@organization, @prompt_template), 
                  alert: 'Archived questions cannot be edited.'
      return
    end

    service = PromptQuestionSaveService.new(@prompt_question)
    result = service.call(prompt_question_params)

    if result[:success]
      redirect_to edit_organization_prompt_template_path(@organization, @prompt_template), 
                  notice: 'Question was successfully updated.'
    else
      @prompt_question.errors.merge!(result[:errors]) if result[:errors]
      @return_url = params[:return_url] || edit_organization_prompt_template_path(@organization, @prompt_template)
      @return_text = params[:return_text] || 'Back to Template'
      @versions = @prompt_question.versions.order(created_at: :desc)
      render :edit, layout: 'overlay', status: :unprocessable_entity
    end
  end

  def archive
    authorize @prompt_question, :archive?

    @prompt_question.update!(archived_at: Time.current)
    redirect_to edit_organization_prompt_template_path(@organization, @prompt_template), 
                notice: 'Question was successfully archived.'
  end

  def unarchive
    authorize @prompt_question, :unarchive?

    @prompt_question.update!(archived_at: nil)
    redirect_to edit_organization_prompt_template_path(@organization, @prompt_template), 
                notice: 'Question was successfully unarchived.'
  end

  def destroy
    authorize @prompt_question
    @prompt_question.destroy
    redirect_to edit_organization_prompt_template_path(@organization, @prompt_template), 
                notice: 'Question was successfully deleted.'
  end

  private

  def set_prompt_template
    company = @organization.root_company || @organization
    @prompt_template = PromptTemplate.find_by(id: params[:prompt_template_id], company: company)
    unless @prompt_template
      redirect_to organization_prompt_templates_path(@organization), 
                  alert: 'Prompt template not found.'
    end
  end

  def set_prompt_question
    @prompt_question = @prompt_template.prompt_questions.find(params[:id])
  end

  def prompt_question_params
    params.require(:prompt_question).permit(:label, :placeholder_text, :helper_text, :position)
  end
end




