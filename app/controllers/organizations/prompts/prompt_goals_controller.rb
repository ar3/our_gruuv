class Organizations::Prompts::PromptGoalsController < Organizations::OrganizationNamespaceBaseController
  before_action :authenticate_person!
  before_action :set_prompt
  before_action :set_prompt_goal, only: [:destroy]

  after_action :verify_authorized

  def create
    authorize PromptGoal.new(prompt: @prompt, goal: Goal.new)
    
    goal_ids = Array(params[:goal_ids]).reject(&:blank?)
    bulk_goal_titles = params[:bulk_goal_titles].to_s.split("\n").map(&:strip).reject(&:blank?)
    
    if goal_ids.empty? && bulk_goal_titles.empty?
      redirect_to manage_goals_organization_prompt_path(@organization, @prompt, return_url: params[:return_url], return_text: params[:return_text]),
                  alert: 'Please select at least one existing goal or provide at least one new goal title.'
      return
    end

    success_count = 0
    errors = []
    company = @organization.root_company || @organization
    current_teammate = current_person.teammates.find_by(organization: company)
    
    unless current_teammate.is_a?(CompanyTeammate)
      redirect_to edit_organization_prompt_path(@organization, @prompt),
                  alert: 'You must be a company teammate to associate goals.'
      return
    end

    # Handle existing goal associations
    goal_ids.each do |goal_id|
      goal = Goal.find_by(id: goal_id)
      next unless goal

      prompt_goal = @prompt.prompt_goals.build(goal: goal)
      authorize prompt_goal

      if prompt_goal.save
        success_count += 1
      else
        errors.concat(prompt_goal.errors.full_messages)
      end
    end

    # Handle bulk goal creation
    owner_teammate = @prompt.company_teammate
    bulk_goal_titles.each do |title|
      goal = Goal.new(
        title: title,
        description: '',
        goal_type: 'stepping_stone_activity',
        most_likely_target_date: Date.current + 90.days,
        earliest_target_date: nil,
        latest_target_date: nil,
        creator: current_teammate,
        privacy_level: 'only_creator_and_owner'
      )
      
      # Explicitly set owner_type and owner_id to preserve STI type
      # Rails polymorphic associations don't preserve STI types, so we need to set them explicitly
      if owner_teammate.respond_to?(:type) && owner_teammate.type == 'CompanyTeammate'
        goal.owner_type = 'CompanyTeammate'
      elsif owner_teammate.is_a?(CompanyTeammate)
        goal.owner_type = 'CompanyTeammate'
      else
        goal.owner_type = owner_teammate.class.base_class.name
      end
      goal.owner_id = owner_teammate.id
      
      if goal.save
        prompt_goal = @prompt.prompt_goals.build(goal: goal)
        authorize prompt_goal
        
        if prompt_goal.save
          success_count += 1
        else
          errors.concat(prompt_goal.errors.full_messages)
        end
      else
        errors.concat(goal.errors.full_messages.map { |msg| "#{title}: #{msg}" })
      end
    end

    if success_count > 0 && errors.empty?
      redirect_to edit_organization_prompt_path(@organization, @prompt),
                  notice: "#{success_count} #{'goal'.pluralize(success_count)} #{success_count == 1 ? 'was' : 'were'} successfully associated."
    elsif success_count > 0 && errors.any?
      redirect_to edit_organization_prompt_path(@organization, @prompt),
                  alert: "Some goals were associated, but there were errors: #{errors.join(', ')}"
    else
      redirect_to manage_goals_organization_prompt_path(@organization, @prompt, return_url: params[:return_url], return_text: params[:return_text]),
                  alert: "Failed to associate goals: #{errors.join(', ')}"
    end
  end

  def destroy
    authorize @prompt_goal
    
    if @prompt_goal.destroy
      redirect_to edit_organization_prompt_path(@organization, @prompt),
                  notice: 'Goal association was successfully removed.'
    else
      redirect_to edit_organization_prompt_path(@organization, @prompt),
                  alert: 'Failed to remove goal association.'
    end
  end

  private

  def set_prompt
    @prompt = Prompt.find(params[:prompt_id])
    company = @organization.root_company || @organization
    unless @prompt.company_teammate.organization.self_and_descendants.include?(company)
      redirect_to organization_prompts_path(@organization), alert: 'Prompt not found or you do not have access.'
    end
  end

  def set_prompt_goal
    @prompt_goal = @prompt.prompt_goals.find(params[:id])
  end
end

