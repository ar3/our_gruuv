class Organizations::PromptsController < Organizations::OrganizationNamespaceBaseController
  before_action :authenticate_person!
  before_action :set_prompt, only: [:edit, :update, :close, :close_and_start_new, :manage_goals]

  after_action :verify_authorized

  def index
    authorize company, :view_prompts?
    
    # Get all active/available templates for the company
    company = @organization.root_company || @organization
    @active_templates = PromptTemplate.where(company: company).available.ordered
    
    # Get current teammate
    current_teammate = current_person.teammates.find_by(organization: company)
    
    # For each template, find active and previous prompts for current user
    @template_prompts = {}
    @active_templates.each do |template|
      if current_teammate
        active_prompt = Prompt.where(company_teammate: current_teammate, prompt_template: template).open.first
        previous_prompts = Prompt.where(company_teammate: current_teammate, prompt_template: template).closed.ordered.limit(10)
        
        @template_prompts[template.id] = {
          active: active_prompt,
          previous: previous_prompts
        }
      else
        @template_prompts[template.id] = {
          active: nil,
          previous: []
        }
      end
    end

    # Prompts from templates that are no longer active (for current user)
    inactive_template_ids = PromptTemplate.where(company: company).where.not(id: @active_templates.select(:id)).pluck(:id)
    inactive_prompts = if current_teammate && inactive_template_ids.any?
      Prompt.where(company_teammate: current_teammate, prompt_template_id: inactive_template_ids)
            .includes(:prompt_template)
            .ordered
    else
      Prompt.none
    end
    @inactive_template_prompts_by_template = inactive_prompts.group_by(&:prompt_template).sort_by { |t, _| t.title }.to_h
  end

  def customize_view
    authorize company, :view_prompts?
    
    # Load current state from params
    query = PromptsQuery.new(@organization, params, current_person: current_person)
    
    @current_filters = query.current_filters
    @current_sort = query.current_sort
    @current_view = query.current_view
    @current_spotlight = query.current_spotlight
    
    # Get available templates and teammates for filters
    @available_templates = PromptTemplate.where(company: company).ordered
    @available_teammates = CompanyTeammate.where(organization: company).includes(:person).order('people.first_name, people.last_name')
    
    # Preserve current params for return URL
    return_params = params.except(:controller, :action, :page).permit!.to_h
    @return_url = organization_prompts_path(@organization, return_params)
    @return_text = "Back to Prompts"
    
    render layout: 'overlay'
  end

  def update_view
    authorize company, :view_prompts?
    
    # Build redirect URL with all view customization params
    redirect_params = params.except(:controller, :action, :authenticity_token, :_method, :commit).permit!.to_h
    
    redirect_to organization_prompts_path(@organization, redirect_params)
  end


  def create
    authorize Prompt, :create?
    
    template = PromptTemplate.find_by(id: params[:template_id], company: @organization.root_company || @organization)
    unless template
      redirect_to organization_prompts_path(@organization), alert: 'Prompt template not found.'
      return
    end
    
    unless template.available?
      redirect_to organization_prompts_path(@organization), alert: 'This prompt template is not available.'
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
    
    @prompt = Prompt.create!(
      company_teammate: teammate,
      prompt_template: template
    )
    
    redirect_to edit_organization_prompt_path(@organization, @prompt), 
                notice: 'Prompt started successfully.'
  rescue ActiveRecord::RecordInvalid => e
    redirect_to organization_prompts_path(@organization), alert: "Error starting prompt: #{e.message}"
  end

  def close_and_start_new
    authorize @prompt, :update?
    
    unless @prompt.open?
      redirect_to edit_organization_prompt_path(@organization, @prompt), 
                  alert: 'This prompt is already closed.'
      return
    end
    
    template = @prompt.prompt_template
    company = @organization.root_company || @organization
    teammate = current_person.teammates.find_by(organization: company)
    
    # Close the current prompt
    @prompt.close!
    
    # Create a new prompt for the same template
    new_prompt = Prompt.create!(
      company_teammate: teammate,
      prompt_template: template
    )
    
    redirect_to edit_organization_prompt_path(@organization, new_prompt), 
                notice: 'Previous reflection closed. New reflection started successfully.'
  rescue ActiveRecord::RecordInvalid => e
    redirect_to edit_organization_prompt_path(@organization, @prompt), 
                alert: "Error starting new prompt: #{e.message}"
  end

  def edit
    authorize @prompt, :show?
    
    @can_edit = policy(@prompt).update?
    
    # If closed, still allow viewing but not editing
    unless @prompt.open?
      @can_edit = false
    end
    
    @prompt_template = @prompt.prompt_template
    # Get active questions for editing, archived for display
    @prompt_questions = @prompt_template.prompt_questions.active.ordered.to_a
    @archived_questions = @prompt_template.prompt_questions.archived.ordered.to_a
    
    # Build prompt_answers hash for form
    @prompt_answers = {}
    @prompt.prompt_answers.each do |answer|
      @prompt_answers[answer.prompt_question_id] = answer
    end
    
    # Create empty answers for active questions that don't have answers yet
    @prompt_questions.each do |question|
      unless @prompt_answers[question.id]
        @prompt_answers[question.id] = @prompt.prompt_answers.build(prompt_question: question)
      end
    end
    
    # Also build answers for archived questions (read-only)
    @archived_answers = {}
    @archived_questions.each do |question|
      if @prompt_answers[question.id]
        @archived_answers[question.id] = @prompt_answers[question.id]
      end
    end
    
    @prompt_goals = @prompt.prompt_goals.includes(:goal).to_a
    
    # Load linked_goals and linked_goal_check_ins for goal hierarchy display
    goal_ids = @prompt.goals.pluck(:id)
    if goal_ids.any?
      # Load all goals including completed and deleted for hierarchy display
      @linked_goals = Goal.where(id: goal_ids).index_by(&:id)
      
      # Preload all descendant goals for hierarchy display
      all_descendant_ids = goal_ids.dup
      current_level_ids = goal_ids.dup
      while current_level_ids.any?
        next_level_ids = GoalLink.where(parent_id: current_level_ids).pluck(:child_id)
        next_level_ids.each { |id| all_descendant_ids << id unless all_descendant_ids.include?(id) }
        current_level_ids = next_level_ids
      end
      
      if all_descendant_ids.any?
        @linked_goals = Goal.where(id: all_descendant_ids).includes(outgoing_links: :child).index_by(&:id)
        @linked_goal_check_ins = GoalCheckIn
          .where(goal_id: all_descendant_ids)
          .includes(:confidence_reporter, :goal)
          .recent
          .group_by(&:goal_id)
          .transform_values { |check_ins| check_ins.first }
      else
        @linked_goals = {}
        @linked_goal_check_ins = {}
      end
    else
      @linked_goals = {}
      @linked_goal_check_ins = {}
    end
    
    # Calculate next prompt for navigation
    if @can_edit
      company = @organization.root_company || @organization
      current_teammate = current_person.teammates.find_by(organization: company)
      @next_prompt = @prompt.next_prompt_for_teammate(current_teammate) if current_teammate
    end

    # Last closed version of this template for this user (for link in Reflection Details)
    @last_closed_prompt = Prompt
      .where(company_teammate: @prompt.company_teammate, prompt_template: @prompt.prompt_template)
      .closed
      .where.not(id: @prompt.id)
      .order(closed_at: :desc)
      .first
  end

  def update
    authorize @prompt, :show?
    
    unless @prompt.open?
      redirect_to edit_organization_prompt_path(@organization, @prompt), 
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
    
    # Determine redirect based on button clicked
    if params[:save_and_manage_goals].present?
      # Save and go to manage goals page
      redirect_to manage_goals_organization_prompt_path(@organization, @prompt, return_url: edit_organization_prompt_path(@organization, @prompt), return_text: @prompt.prompt_template.title),
                  notice: 'Prompt answers saved successfully.'
    elsif params[:save_and_edit_goals].present?
      # Save and go to goals index with teammate selected and prompt filter
      redirect_to organization_goals_path(@organization, owner_type: 'CompanyTeammate', owner_id: current_teammate.id, prompt_id: @prompt.id),
                  notice: 'Prompt answers saved. Showing goals for this reflection.'
    elsif params[:save_and_close_and_start_new].present?
      # Save, close current prompt, create new prompt, redirect to edit new
      template = @prompt.prompt_template
      @prompt.close!
      new_prompt = Prompt.create!(
        company_teammate: current_teammate,
        prompt_template: template
      )
      redirect_to edit_organization_prompt_path(@organization, new_prompt),
                  notice: "Fresh #{@organization.display_name}: #{template.title} started."
    elsif params[:save_and_next].present?
      # Save and go to next prompt
      next_prompt = @prompt.next_prompt_for_teammate(current_teammate)
      if next_prompt
        redirect_to edit_organization_prompt_path(@organization, next_prompt), 
                    notice: 'Prompt updated successfully.'
      else
        redirect_to organization_prompts_path(@organization), 
                    notice: 'Prompt updated successfully.'
      end
    elsif params[:save_and_continue].present?
      # Save and continue editing
      redirect_to edit_organization_prompt_path(@organization, @prompt), 
                  notice: 'Prompt updated successfully.'
    else
      # Default: redirect to edit page
      redirect_to edit_organization_prompt_path(@organization, @prompt), 
                  notice: 'Prompt updated successfully.'
    end
  rescue ActiveRecord::RecordInvalid => e
    @can_edit = policy(@prompt).update?
    @prompt_template = @prompt.prompt_template
    @prompt_questions = @prompt_template.prompt_questions.active.ordered.to_a
    @archived_questions = @prompt_template.prompt_questions.archived.ordered.to_a
    @prompt_answers = {}
    @prompt.prompt_answers.each do |answer|
      @prompt_answers[answer.prompt_question_id] = answer
    end
    @archived_answers = {}
    @archived_questions.each do |question|
      if @prompt_answers[question.id]
        @archived_answers[question.id] = @prompt_answers[question.id]
      end
    end
    @prompt_goals = @prompt.prompt_goals.includes(:goal).to_a
    flash.now[:alert] = "Error updating prompt: #{e.message}"
    render :edit, status: :unprocessable_entity
  end

  def close
    authorize @prompt
    
    unless @prompt.open?
      redirect_to edit_organization_prompt_path(@organization, @prompt), 
                  alert: 'This prompt is already closed.'
      return
    end
    
    @prompt.close!
    redirect_to edit_organization_prompt_path(@organization, @prompt), 
                notice: 'Prompt closed successfully.'
  end

  def manage_goals
    authorize @prompt, :update?
    
    company = @organization.root_company || @organization
    current_teammate = current_person.teammates.find_by(organization: company)
    
    # Get available goals for the current teammate
    available_goals = Goal.for_teammate(current_teammate)
                          .where(deleted_at: nil, completed_at: nil)
                          .includes(:owner, :creator)
    
    # Mark which goals are already associated
    @available_goals_with_status = available_goals.map do |goal|
      {
        goal: goal,
        already_linked: @prompt.goals.include?(goal)
      }
    end
    
    @return_url = params[:return_url] || edit_organization_prompt_path(@organization, @prompt)
    @return_text = params[:return_text] || 'Back to Prompt'
    
    render layout: 'overlay'
  end

  private

  def set_prompt
    # Prevent collection route names from being treated as IDs
    if params[:id].present? && !params[:id].match?(/\A[0-9]+\z/)
      raise ActiveRecord::RecordNotFound, "Couldn't find Prompt with 'id'=#{params[:id].inspect}"
    end
    
    @prompt = Prompt.includes(company_teammate: :person).find(params[:id])
  end
end

