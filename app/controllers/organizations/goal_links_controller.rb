class Organizations::GoalLinksController < Organizations::OrganizationNamespaceBaseController
  before_action :authenticate_person!
  before_action :set_goal
  
  after_action :verify_authorized
  
  def create
    @goal_link = GoalLink.new(this_goal: @goal)
    @form = GoalLinkForm.new(@goal_link)
    
    goal_link_params = params[:goal_link] || {}
    
    if @form.validate(goal_link_params) && @form.save
      redirect_to organization_goal_path(@organization, @goal), 
                  notice: 'Goal link was successfully created.'
    else
      # If AJAX request, render JSON with errors
      if request.format.json?
        render json: { errors: @form.errors.full_messages }, status: :unprocessable_entity
      else
        # Redirect to goal show page with error message
        redirect_to organization_goal_path(@organization, @goal),
                    alert: "Failed to create link: #{@form.errors.full_messages.join(', ')}"
      end
    end
  end
  
  def destroy
    @goal_link = @goal.outgoing_links.find(params[:id])
    authorize @goal_link
    
    @goal_link.destroy
    redirect_to organization_goal_path(@organization, @goal),
                notice: 'Goal link was successfully deleted.'
  end
  
  private
  
  def set_goal
    @goal = Goal.find(params[:goal_id])
    authorize @goal
  end
end

