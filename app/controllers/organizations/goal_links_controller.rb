class Organizations::GoalLinksController < Organizations::OrganizationNamespaceBaseController
  before_action :authenticate_person!
  before_action :set_goal, except: [:new_outgoing_link, :new_incoming_link]
  
  after_action :verify_authorized
  
  def new_outgoing_link
    @organization = Organization.find(params[:organization_id])
    @goal = Goal.find(params[:goal_id])
    authorize @goal, :update?
    
    @direction = 'outgoing'
    @available_goals = Goal.for_teammate(current_person.teammates.find_by(organization: @organization))
                          .where.not(id: @goal.id)
    
    @return_url = params[:return_url] || organization_goal_path(@organization, @goal)
    @return_text = params[:return_text] || 'Goal'
    
    render layout: 'overlay'
  end
  
  def new_incoming_link
    @organization = Organization.find(params[:organization_id])
    @goal = Goal.find(params[:goal_id])
    authorize @goal, :update?
    
    @direction = 'incoming'
    @available_goals = Goal.for_teammate(current_person.teammates.find_by(organization: @organization))
                          .where.not(id: @goal.id)
    
    @return_url = params[:return_url] || organization_goal_path(@organization, @goal)
    @return_text = params[:return_text] || 'Goal'
    
    render layout: 'overlay'
  end
  
  def create
    goal_link_params = params[:goal_link] || {}
    goal_ids = params[:goal_ids] || []
    bulk_goal_titles = params[:bulk_goal_titles]
    link_direction = params[:link_direction] || goal_link_params[:link_direction] || 'outgoing'
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
        redirect_to new_outgoing_link_organization_goal_goal_links_path(@organization, @goal, return_url: return_url, return_text: params[:return_text]),
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
          link_direction: link_direction,
          link_type: 'this_is_key_result_of_that'
        }
        
        if link_direction == 'incoming'
          form_params[:this_goal_id] = goal_id
        else
          form_params[:that_goal_id] = goal_id
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
        goal_type = link_direction == 'incoming' ? 'inspirational_objective' : 'quantitative_key_result'
        
        titles.each do |title|
          goal_link = GoalLink.new
          form = GoalLinkForm.new(goal_link)
          form.organization = @organization
          form.current_person = current_person
          form.current_teammate = current_person.teammates.find_by(organization: @organization)
          form.linking_goal = @goal
          
          form_params = {
            link_direction: link_direction,
            link_type: 'this_is_key_result_of_that',
            bulk_create_mode: true,
            bulk_goal_titles: title
          }
          
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
        redirect_to new_outgoing_link_organization_goal_goal_links_path(@organization, @goal, return_url: return_url, return_text: params[:return_text]),
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
    @goal = Goal.find(params[:goal_id])
    authorize @goal
  end
end

