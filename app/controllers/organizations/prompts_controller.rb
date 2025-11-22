class Organizations::PromptsController < Organizations::OrganizationNamespaceBaseController
  before_action :authenticate_person!
  before_action :set_prompt, only: [:show, :edit, :update, :close]

  after_action :verify_authorized, except: :index
  after_action :verify_policy_scoped, only: :index

  def index
    @prompts = policy_scope(Prompt)
    
    # Use PromptsQuery for filtering and sorting
    query = PromptsQuery.new(@organization, params, current_person: current_person)
    
    # Get filtered prompts (before sorting)
    filtered_prompts = query.base_scope
    filtered_prompts = query.filter_by_template(filtered_prompts)
    filtered_prompts = query.filter_by_status(filtered_prompts)
    filtered_prompts = query.filter_by_teammate(filtered_prompts)
    
    # Count before applying complex sorts
    total_count = filtered_prompts.count
    
    # Apply sorting
    sorted_prompts = query.call
    
    # Eager load associations
    sorted_prompts = sorted_prompts.includes(
      :prompt_template,
      { company_teammate: :person },
      { prompt_answers: :prompt_question }
    )
    
    # Paginate using Pagy (25 items per page)
    @pagy = Pagy.new(count: total_count, page: params[:page] || 1, items: 25)
    @prompts = sorted_prompts.limit(@pagy.items).offset(@pagy.offset)
    
    # Store current filter/sort/view/spotlight state for view
    @current_filters = query.current_filters
    @current_sort = query.current_sort
    @current_view = query.current_view
    @current_spotlight = query.current_spotlight
    
    # Get available templates and teammates for filters
    company = @organization.root_company || @organization
    @available_templates = PromptTemplate.where(company: company).ordered
    @available_teammates = CompanyTeammate.where(organization: company).includes(:person).order('people.first_name, people.last_name')
  end

  def customize_view
    authorize Prompt, :index?
    
    # Load current state from params
    query = PromptsQuery.new(@organization, params, current_person: current_person)
    
    @current_filters = query.current_filters
    @current_sort = query.current_sort
    @current_view = query.current_view
    @current_spotlight = query.current_spotlight
    
    # Get available templates and teammates for filters
    company = @organization.root_company || @organization
    @available_templates = PromptTemplate.where(company: company).ordered
    @available_teammates = CompanyTeammate.where(organization: company).includes(:person).order('people.first_name, people.last_name')
    
    # Preserve current params for return URL
    return_params = params.except(:controller, :action, :page).permit!.to_h
    @return_url = organization_prompts_path(@organization, return_params)
    @return_text = "Back to Prompts"
    
    render layout: 'overlay'
  end

  def update_view
    authorize Prompt, :index?
    
    # Build redirect URL with all view customization params
    redirect_params = params.except(:controller, :action, :authenticity_token, :_method, :commit).permit!.to_h
    
    redirect_to organization_prompts_path(@organization, redirect_params)
  end

  def show
    authorize @prompt
    @prompt_answers = @prompt.prompt_answers
      .includes(:prompt_question)
      .joins(:prompt_question)
      .order('prompt_questions.position')
      .to_a
  end

  def new
    authorize Prompt, :create?
    
    company = @organization.root_company || @organization
    teammate = current_person.teammates.find_by(organization: company)
    unless teammate.is_a?(CompanyTeammate)
      redirect_to organization_prompts_path(@organization), alert: 'You must be a company teammate to start a prompt.'
      return
    end
    
    @available_templates = PromptTemplate.where(company: company).available.ordered
    @existing_open_prompts = Prompt.where(company_teammate: teammate).open.includes(:prompt_template).index_by(&:prompt_template_id)
  end

  def create
    authorize Prompt, :create?
    
    template = PromptTemplate.find_by(id: params[:template_id], company: @organization.root_company || @organization)
    unless template
      redirect_to new_organization_prompt_path(@organization), alert: 'Prompt template not found.'
      return
    end
    
    unless template.available?
      redirect_to new_organization_prompt_path(@organization), alert: 'This prompt template is not available.'
      return
    end
    
    company = @organization.root_company || @organization
    teammate = current_person.teammates.find_by(organization: company)
    unless teammate.is_a?(CompanyTeammate)
      redirect_to organization_prompts_path(@organization), alert: 'You must be a company teammate to start a prompt.'
      return
    end
    
    # Check if there's already an open prompt for this template
    existing_open = Prompt.where(company_teammate: teammate, prompt_template: template).open.first
    if existing_open
      # Close the existing prompt and create a new one
      existing_open.close!
    end
    
    # Check if there's any other open prompt (shouldn't happen due to validation, but check anyway)
    other_open = Prompt.where(company_teammate: teammate).open.where.not(prompt_template: template).first
    if other_open
      redirect_to new_organization_prompt_path(@organization), 
                  alert: 'You already have an open prompt for a different template. Please close it before starting a new one.'
      return
    end
    
    @prompt = Prompt.create!(
      company_teammate: teammate,
      prompt_template: template
    )
    
    redirect_to edit_organization_prompt_path(@organization, @prompt), 
                notice: 'Prompt started successfully.'
  rescue ActiveRecord::RecordInvalid => e
    redirect_to new_organization_prompt_path(@organization), alert: "Error starting prompt: #{e.message}"
  end

  def edit
    authorize @prompt, :show?
    
    unless @prompt.open?
      redirect_to organization_prompt_path(@organization, @prompt), 
                  alert: 'This prompt is closed and cannot be edited.'
      return
    end
    
    authorize @prompt, :update?
    
    @prompt_template = @prompt.prompt_template
    @prompt_questions = @prompt_template.prompt_questions.ordered.to_a
    
    # Build prompt_answers hash for form
    @prompt_answers = {}
    @prompt.prompt_answers.each do |answer|
      @prompt_answers[answer.prompt_question_id] = answer
    end
    
    # Create empty answers for questions that don't have answers yet
    @prompt_questions.each do |question|
      unless @prompt_answers[question.id]
        @prompt_answers[question.id] = @prompt.prompt_answers.build(prompt_question: question)
      end
    end
    
    # Determine view style (vertical or split)
    @view_style = params[:view] || 'split'
    @view_style = 'split' unless ['vertical', 'split'].include?(@view_style)
  end

  def update
    authorize @prompt, :show?
    
    unless @prompt.open?
      redirect_to organization_prompt_path(@organization, @prompt), 
                  alert: 'This prompt is closed and cannot be edited.'
      return
    end
    
    authorize @prompt, :update?
    
    company = @organization.root_company || @organization
    current_teammate = current_person.teammates.find_by(organization: company)
    
    # Update answers
    if params[:prompt_answers].present?
      params[:prompt_answers].each do |question_id, answer_params|
        answer = @prompt.prompt_answers.find_or_initialize_by(prompt_question_id: question_id)
        
        # Track if text changed for updated_by
        text_changed = answer.text != answer_params[:text]
        answer.text = answer_params[:text]
        
        # Update updated_by if text changed
        if text_changed && current_teammate
          answer.updated_by_company_teammate_id = current_teammate.id
        end
        
        answer.save!
      end
    end
    
    # Check if this is a view switch request
    target_view = params[:switch_to_view]
    if target_view.present? && ['vertical', 'split'].include?(target_view)
      redirect_to edit_organization_prompt_path(@organization, @prompt, view: target_view), 
                  notice: 'Prompt updated successfully.'
    else
      redirect_to organization_prompt_path(@organization, @prompt), 
                  notice: 'Prompt updated successfully.'
    end
  rescue ActiveRecord::RecordInvalid => e
    @prompt_template = @prompt.prompt_template
    @prompt_questions = @prompt_template.prompt_questions.ordered
    @prompt_answers = {}
    @prompt.prompt_answers.each do |answer|
      @prompt_answers[answer.prompt_question_id] = answer
    end
    @view_style = params[:view] || 'split'
    flash.now[:alert] = "Error updating prompt: #{e.message}"
    render :edit, status: :unprocessable_entity
  end

  def close
    authorize @prompt
    
    unless @prompt.open?
      redirect_to organization_prompt_path(@organization, @prompt), 
                  alert: 'This prompt is already closed.'
      return
    end
    
    @prompt.close!
    redirect_to organization_prompt_path(@organization, @prompt), 
                notice: 'Prompt closed successfully.'
  end

  private

  def set_prompt
    # Prevent collection route names from being treated as IDs
    if params[:id].present? && !params[:id].match?(/\A[0-9]+\z/)
      raise ActiveRecord::RecordNotFound, "Couldn't find Prompt with 'id'=#{params[:id].inspect}"
    end
    
    @prompt = Prompt.find(params[:id])
  end
end

