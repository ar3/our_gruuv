class Organizations::GoalLinksController < Organizations::OrganizationNamespaceBaseController
  before_action :authenticate_person!
  before_action :set_goal, except: [:new_outgoing_link, :new_incoming_link, :choose_incoming_link, :associate_existing_incoming]

  after_action :verify_authorized

  def choose_incoming_link
    @organization = Organization.find(params[:organization_id])
    @goal = Goal.find(params[:goal_id])
    authorize @goal, :update?
    @return_url = params[:return_url] || organization_goal_path(@organization, @goal)
    @return_text = params[:return_text] || 'Goal'
    render layout: 'overlay'
  end

  def associate_existing_incoming
    @organization = Organization.find(params[:organization_id])
    @goal = Goal.find(params[:goal_id])
    authorize @goal, :update?

    if request.get?
      current_teammate = current_person.teammates.find_by(organization: @organization)
      candidate_goals = Goals::ParentCandidatesQuery.new(goal: @goal, current_teammate: current_teammate).call
      hierarchy_ids = Goals::GoalHierarchyIdsQuery.new(@goal).call
      @available_goals_with_status = candidate_goals.map do |g|
        { goal: g, in_hierarchy: hierarchy_ids.include?(g.id) }
      end
      @return_url = params[:return_url] || organization_goal_path(@organization, @goal)
      @return_text = params[:return_text] || 'Goal'
      render layout: 'overlay'
      return
    end

    # POST: create links from goal_ids[]
    goal_ids = Array(params[:goal_ids]).reject(&:blank?)
    return_url = params[:return_url] || organization_goal_path(@organization, @goal)

    if goal_ids.empty?
      redirect_to associate_existing_incoming_organization_goal_goal_links_path(
        @organization, @goal, return_url: return_url, return_text: params[:return_text]
      ), alert: 'Please select at least one goal.'
      return
    end

    success_count = 0
    errors = []
    current_teammate = current_person.teammates.find_by(organization: @organization)

    goal_ids.each do |goal_id|
      goal_link = GoalLink.new
      form = GoalLinkForm.new(goal_link)
      form.organization = @organization
      form.current_person = current_person
      form.current_teammate = current_teammate
      form.linking_goal = @goal
      form_params = { link_direction: 'incoming', parent_id: goal_id }
      form_params[:metadata_notes] = params[:metadata_notes] if params[:metadata_notes].present?

      if form.validate(form_params) && form.save
        success_count += 1
      else
        errors.concat(form.errors.full_messages)
      end
    end

    if success_count > 0 && errors.empty?
      redirect_to return_url, notice: 'Goal link was successfully created.'
    elsif success_count > 0 && errors.any?
      redirect_to return_url, alert: "Some links were created, but there were errors: #{errors.join(', ')}"
    else
      redirect_to associate_existing_incoming_organization_goal_goal_links_path(
        @organization, @goal, return_url: return_url, return_text: params[:return_text]
      ), alert: "Failed to create links: #{errors.join(', ')}"
    end
  end

  def new_outgoing_link
    @organization = Organization.find(params[:organization_id])
    @goal = Goal.find(params[:goal_id])
    authorize @goal, :update?
    
    @direction = 'outgoing'
    @goal_type = params[:goal_type] || 'stepping_stone_activity'
    # Don't filter by started_at for goal linking - allow linking to draft goals
    available_goals = Goal.for_teammate(current_person.teammates.find_by(organization: @organization))
                          .where(deleted_at: nil, completed_at: nil)
                          .where.not(id: @goal.id)
                          .where(goal_type: @goal_type)
    available_goals = available_goals.owned_by_teammate if @goal.owner_type == 'CompanyTeammate'

    @available_goals_with_status = available_goals.map do |candidate_goal|
      {
        goal: candidate_goal,
        would_create_circular_dependency: would_create_circular_dependency?(candidate_goal, @goal, 'outgoing'),
        already_linked: already_linked?(candidate_goal, @goal, 'outgoing'),
        existing_link: existing_link_for_goal(candidate_goal, @goal, 'outgoing')
      }
    end
    
    @return_url = params[:return_url] || organization_goal_path(@organization, @goal)
    @return_text = params[:return_text] || 'Goal'
    
    render layout: 'overlay'
  end
  
  def new_incoming_link
    @organization = Organization.find(params[:organization_id])
    @goal = Goal.find(params[:goal_id])
    authorize @goal, :update?
    @direction = 'incoming'
    @return_url = params[:return_url] || organization_goal_path(@organization, @goal)
    @return_text = params[:return_text] || 'Goal'
    render layout: 'overlay'
  end
  
  def create
    authorize @goal, :update? # Must be able to update the goal to create links
    
    goal_link_params = params[:goal_link] || {}
    goal_ids = params[:goal_ids] || []
    bulk_goal_titles = params[:bulk_goal_titles]
    link_direction = params[:link_direction] || goal_link_params[:link_direction] || 'outgoing'
    goal_type = params[:goal_type] || (link_direction == 'outgoing' ? 'stepping_stone_activity' : 'inspirational_objective')
    return_url = params[:return_url] || organization_goal_path(@organization, @goal)
    
    # Validate that at least one option is provided
    goal_ids = Array(goal_ids).reject(&:blank?)
    bulk_titles = bulk_goal_titles.to_s.split("\n").map(&:strip).reject(&:blank?)
    
    if goal_ids.empty? && bulk_titles.empty?
      error_msg = "Please select at least one existing goal or provide at least one new goal title"
      if link_direction == 'incoming'
        redirect_to new_incoming_link_organization_goal_goal_links_path(@organization, @goal, return_url: return_url, return_text: params[:return_text]),
                    alert: error_msg
      else
        redirect_to new_outgoing_link_organization_goal_goal_links_path(@organization, @goal, goal_type: goal_type, return_url: return_url, return_text: params[:return_text]),
                    alert: error_msg
      end
      return
    end
    
    success_count = 0
    errors = []
    
    # Handle existing goal links
    if goal_ids.present?
      goal_ids.each do |goal_id|
        next if goal_id.blank?
        
        goal_link = GoalLink.new
        form = GoalLinkForm.new(goal_link)
        form.organization = @organization
        form.current_person = current_person
        form.current_teammate = current_person.teammates.find_by(organization: @organization)
        form.linking_goal = @goal
        
        form_params = {
          link_direction: link_direction
        }
        
        if link_direction == 'incoming'
          form_params[:parent_id] = goal_id
        else
          form_params[:child_id] = goal_id
        end
        
        # Add metadata notes if provided
        if params[:metadata_notes].present?
          form_params[:metadata_notes] = params[:metadata_notes]
        end
        
        if form.validate(form_params) && form.save
          success_count += 1
        else
          errors.concat(form.errors.full_messages)
        end
      end
    end
    
    # Handle bulk goal creation
    if bulk_titles.present?
      titles = bulk_titles
      
      unless titles.empty?
        goal_link = GoalLink.new
        form = GoalLinkForm.new(goal_link)
        form.organization = @organization
        form.current_person = current_person
        form.current_teammate = current_person.teammates.find_by(organization: @organization)
        form.linking_goal = @goal
        
        # Pass all titles as newline-separated string
        form_params = {
          link_direction: link_direction,
          bulk_create_mode: true,
          bulk_goal_titles: titles.join("\n"),
          goal_type: goal_type
        }
        
        # Add metadata notes if provided
        if params[:metadata_notes].present?
          form_params[:metadata_notes] = params[:metadata_notes]
        end
        
        if form.validate(form_params) && form.save
          # Count how many goals were created
          success_count += form.bulk_create_service&.created_goals&.count || 0
        else
          errors.concat(form.errors.full_messages)
        end
      end
    end
    
    # Validate that at least one operation succeeded
    if success_count > 0 && errors.empty?
      redirect_to return_url, notice: 'Goal link was successfully created.'
    elsif success_count > 0 && errors.any?
      redirect_to return_url, alert: "Some links were created, but there were errors: #{errors.join(', ')}"
    else
      # Redirect back to the overlay page with errors
      if link_direction == 'incoming'
        redirect_to new_incoming_link_organization_goal_goal_links_path(@organization, @goal, return_url: return_url, return_text: params[:return_text]),
                    alert: "Failed to create links: #{errors.join(', ')}"
      else
        redirect_to new_outgoing_link_organization_goal_goal_links_path(@organization, @goal, goal_type: goal_type, return_url: return_url, return_text: params[:return_text]),
                    alert: "Failed to create links: #{errors.join(', ')}"
      end
    end
  end
  
  def destroy
    # Check both outgoing and incoming links
    @goal_link = @goal.outgoing_links.find_by(id: params[:id]) || 
                 @goal.incoming_links.find_by(id: params[:id])
    authorize @goal_link if @goal_link
    
    if @goal_link
      @goal_link.destroy
      redirect_to organization_goal_path(@organization, @goal),
                  notice: 'Goal link was successfully deleted.'
    else
      redirect_to organization_goal_path(@organization, @goal),
                  alert: 'Goal link not found.'
    end
  end
  
  private
  
  def set_goal
    # Load goal without scoping - policy will handle authorization checks
    @goal = Goal.find(params[:goal_id])
    @organization = Organization.find(params[:organization_id])
    authorize @goal
  end
  
  def would_create_circular_dependency?(candidate_goal, linking_goal, direction)
    if direction == 'outgoing'
      # For outgoing: Check if linking_goal -> candidate_goal would create a cycle
      # This means checking if candidate_goal has a path back to linking_goal
      creates_cycle?(linking_goal, candidate_goal)
    else # incoming
      # For incoming: Check if candidate_goal -> linking_goal would create a cycle
      # This means checking if linking_goal has a path back to candidate_goal
      creates_cycle?(candidate_goal, linking_goal)
    end
  end
  
  def creates_cycle?(parent_goal, child_goal)
    # BFS to check if child_goal eventually links back to parent_goal
    visited = Set.new
    queue = [child_goal]
    
    while queue.any?
      current = queue.shift
      return true if current.id == parent_goal.id
      
      next if visited.include?(current.id)
      visited.add(current.id)
      
      # Follow outgoing links from current goal (goals where current is the parent)
      current.outgoing_links.each do |link|
        queue << link.child
      end
    end
    
    false
  end
  
  def already_linked?(candidate_goal, linking_goal, direction)
    existing_link_for_goal(candidate_goal, linking_goal, direction).present?
  end
  
  def existing_link_for_goal(candidate_goal, linking_goal, direction)
    if direction == 'outgoing'
      GoalLink.find_by(
        parent: linking_goal,
        child: candidate_goal
      )
    else # incoming
      GoalLink.find_by(
        parent: candidate_goal,
        child: linking_goal
      )
    end
  end
end

