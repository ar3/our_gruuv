class Organizations::CompanyTeammates::OneOnOneLinksController < Organizations::OrganizationNamespaceBaseController
  before_action :authenticate_person!
  before_action :set_teammate
  before_action :set_one_on_one_link

  def show
    authorize @one_on_one_link
    @person = @teammate.person
    @source = @one_on_one_link&.external_project_source
    
    # Check if viewing user has access to the Asana project
    if @source == 'asana' && current_company_teammate&.has_asana_identity? && @one_on_one_link&.asana_project_id
      @has_project_access = check_asana_project_access(@one_on_one_link.asana_project_id)
    else
      @has_project_access = nil
    end
  end

  def create
    authorize @one_on_one_link, :update?
    
    url = one_on_one_link_params[:url]
    
    # Extract project ID if it's an external project link
    if url.present?
      source = ExternalProjectUrlParser.detect_source(url)
      if source == 'asana'
        project_id = extract_asana_project_id(url)
        if project_id
          @one_on_one_link.deep_integration_config ||= {}
          @one_on_one_link.deep_integration_config['asana_project_id'] = project_id
        end
      end
    end
    
    @one_on_one_link.assign_attributes(one_on_one_link_params)
    if @one_on_one_link.save
      redirect_to organization_company_teammate_one_on_one_link_path(organization, @teammate), notice: '1:1 link created successfully.'
    else
      render :show, status: :unprocessable_entity
    end
  end

  def update
    authorize @one_on_one_link
    
    url = one_on_one_link_params[:url]
    
    # Extract project ID if it's an external project link
    if url.present?
      source = ExternalProjectUrlParser.detect_source(url)
      if source == 'asana'
        project_id = extract_asana_project_id(url)
        if project_id
          @one_on_one_link.deep_integration_config ||= {}
          @one_on_one_link.deep_integration_config['asana_project_id'] = project_id
        end
      end
    end
    
    @one_on_one_link.assign_attributes(one_on_one_link_params)
    if @one_on_one_link.save
      redirect_to organization_company_teammate_one_on_one_link_path(organization, @teammate), notice: '1:1 link updated successfully.'
    else
      render :show, status: :unprocessable_entity
    end
  end

  def sync
    authorize @one_on_one_link, :update?
    
    source = params[:source] || @one_on_one_link.external_project_source
    return redirect_to organization_company_teammate_one_on_one_link_path(organization, @teammate), alert: 'No project source detected.' unless source.present?
    
    result = ExternalProjectCacheService.sync_project(@one_on_one_link, source, current_company_teammate)
    
    if result[:success]
      redirect_to organization_company_teammate_one_on_one_link_path(organization, @teammate), notice: 'Project synced successfully.'
    else
      error_message = format_sync_error_message(result, source)
      # Store error type in flash for view to use
      flash[:sync_error_type] = result[:error_type]
      redirect_to organization_company_teammate_one_on_one_link_path(organization, @teammate), alert: error_message
    end
  end

  def associate_project
    authorize @one_on_one_link, :update?
    # Future: Implement project association logic
    redirect_to organization_company_teammate_one_on_one_link_path(organization, @teammate), notice: 'Project association not yet implemented.'
  end

  def disassociate_project
    authorize @one_on_one_link, :update?
    
    source = params[:source] || @one_on_one_link.external_project_source
    return redirect_to organization_company_teammate_one_on_one_link_path(organization, @teammate), alert: 'No project source detected.' unless source.present?
    
    cache = @one_on_one_link.external_project_cache_for(source)
    if cache
      cache.destroy
      redirect_to organization_company_teammate_one_on_one_link_path(organization, @teammate), notice: 'Project cache removed successfully.'
    else
      redirect_to organization_company_teammate_one_on_one_link_path(organization, @teammate), alert: 'No cache found to remove.'
    end
  end

  private

  def format_sync_error_message(result, source)
    error_type = result[:error_type] || 'unknown_error'
    base_message = result[:error] || 'Unknown error occurred'
    
    case error_type
    when 'token_expired'
      source_name = source == 'asana' ? 'Asana' : source.titleize
      "Your #{source_name} token has expired. Please reconnect your account to sync the project."
    when 'permission_denied'
      "You do not have permission to access this project. #{base_message}"
    when 'not_found', 'project_not_found'
      "Project not found. Please verify the project URL is correct."
    when 'not_authenticated'
      source_name = source == 'asana' ? 'Asana' : source.titleize
      "You are not authenticated with #{source_name}. Please connect your account first."
    when 'network_error'
      "Network error: #{base_message}. Please try again later."
    when 'api_error'
      "API error: #{base_message}. Please try again later."
    else
      "Failed to sync project: #{base_message}"
    end
  end

  def associate_project
    authorize @one_on_one_link, :update?
    # Future: Implement project association logic
    redirect_to organization_company_teammate_one_on_one_link_path(organization, @teammate), notice: 'Project association not yet implemented.'
  end

  def disassociate_project
    authorize @one_on_one_link, :update?
    
    source = params[:source] || @one_on_one_link.external_project_source
    return redirect_to organization_company_teammate_one_on_one_link_path(organization, @teammate), alert: 'No project source detected.' unless source.present?
    
    cache = @one_on_one_link.external_project_cache_for(source)
    if cache
      cache.destroy
      redirect_to organization_company_teammate_one_on_one_link_path(organization, @teammate), notice: 'Project cache removed successfully.'
    else
      redirect_to organization_company_teammate_one_on_one_link_path(organization, @teammate), alert: 'No cache found to remove.'
    end
  end

  private

  def set_teammate
    @teammate = organization.teammates.find(params[:company_teammate_id])
    unless @teammate
      redirect_to organization_company_teammate_path(organization, @teammate), 
                  alert: 'Teammate not found for this organization.'
    end
  end

  def extract_asana_project_id(url)
    AsanaUrlParser.extract_project_id(url)
  end

  def set_one_on_one_link
    if @teammate
      @one_on_one_link = @teammate.one_on_one_link || OneOnOneLink.new(teammate: @teammate)
    else
      @one_on_one_link = nil
    end
  end

  def one_on_one_link_params
    params.require(:one_on_one_link).permit(:url)
  end

  def check_asana_project_access(project_id)
    return false unless current_company_teammate&.has_asana_identity?
    
    service = AsanaService.new(current_company_teammate)
    return false unless service.authenticated?
    
    # Try to fetch the project to check access
    project = service.fetch_project(project_id)
    
    # If project is nil, check if it was a permission error
    # We'll check the sections endpoint which is more reliable for access
    sections_result = service.fetch_project_sections(project_id)
    
    if sections_result[:success]
      true
    elsif sections_result[:error] == 'permission_denied'
      false
    else
      # For other errors (not_found, network_error, etc.), assume no access
      # The actual sync will handle these errors appropriately
      false
    end
  end
end



