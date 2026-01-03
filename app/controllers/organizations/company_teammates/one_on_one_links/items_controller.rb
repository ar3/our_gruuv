class Organizations::CompanyTeammates::OneOnOneLinks::ItemsController < Organizations::OrganizationNamespaceBaseController
  before_action :authenticate_person!
  before_action :set_teammate
  before_action :set_one_on_one_link
  before_action :set_item

  def show
    authorize @one_on_one_link
    @person = @teammate.person
    @source = params[:source] || @one_on_one_link.external_project_source
    
    unless @source.present?
      redirect_to organization_company_teammate_one_on_one_link_path(organization, @teammate), 
                  alert: 'No project source detected.'
      return
    end
    
    # Fetch item details from external API
    item_result = fetch_item_details(@item_gid, @source)
    
    unless item_result && item_result[:success]
      error_msg = item_result&.dig(:message) || item_result&.dig(:error) || 'Item not found or could not be fetched.'
      redirect_to organization_company_teammate_one_on_one_link_path(organization, @teammate), 
                  alert: error_msg
      return
    end
    
    @item_details = item_result[:task]
    
    # Use overlay layout
    render layout: 'overlay'
  end

  private

  def set_teammate
    @teammate = organization.teammates.find(params[:company_teammate_id])
    unless @teammate
      redirect_to organization_company_teammate_path(organization, @teammate), 
                  alert: 'Teammate not found for this organization.'
    end
  end

  def set_one_on_one_link
    if @teammate
      @one_on_one_link = @teammate.one_on_one_link
      unless @one_on_one_link
        redirect_to organization_company_teammate_path(organization, @teammate), 
                    alert: '1:1 link not found.'
      end
    else
      @one_on_one_link = nil
    end
  end

  def set_item
    @item_gid = params[:id] || params[:item_gid]
    unless @item_gid.present?
      redirect_to organization_company_teammate_one_on_one_link_path(organization, @teammate), 
                  alert: 'Item ID required.'
    end
  end

  def fetch_item_details(item_gid, source)
    case source
    when 'asana'
      service = AsanaService.new(@teammate)
      if service.authenticated?
        task = service.fetch_task_details(item_gid)
        if task
          { success: true, task: task }
        else
          { success: false, error: 'Task not found' }
        end
      else
        { success: false, error: 'Not authenticated with Asana' }
      end
    when 'jira'
      # Future: JiraService.new(@teammate).fetch_issue_details(item_gid)
      { success: false, error: 'Jira integration not yet implemented' }
    when 'linear'
      # Future: LinearService.new(@teammate).fetch_issue_details(item_gid)
      { success: false, error: 'Linear integration not yet implemented' }
    else
      { success: false, error: 'Unknown source' }
    end
  end
end

