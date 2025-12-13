class Organizations::CompanyTeammates::OneOnOneLinksController < Organizations::OrganizationNamespaceBaseController
  before_action :authenticate_person!
  before_action :set_teammate
  before_action :set_one_on_one_link

  def show
    authorize @one_on_one_link
    @person = @teammate.person
    
    # If Asana integration is active, fetch project data
    if @one_on_one_link&.is_asana_link? && @one_on_one_link.has_deep_integration? && @teammate&.has_asana_identity?
      asana_service = AsanaService.new(@teammate)
      project_id = @one_on_one_link.asana_project_id
      
      if project_id && asana_service.authenticated?
        # Fetch project sections
        @asana_sections = asana_service.fetch_project_sections(project_id)
        
        # Fetch incomplete tasks for each section
        @asana_section_tasks = {}
        @asana_sections.each do |section|
          tasks = asana_service.fetch_section_tasks(section['gid'])
          @asana_section_tasks[section['gid']] = tasks.reject { |task| task['completed'] == true }
        end
      else
        @asana_sections = []
        @asana_section_tasks = {}
      end
    else
      @asana_sections = []
      @asana_section_tasks = {}
    end
  end

  def update
    authorize @one_on_one_link
    
    url = one_on_one_link_params[:url]
    
    # Extract Asana project ID if it's an Asana link
    if url.present?
      # Check if it's an Asana link (need to check before assigning attributes)
      is_asana = url.include?('app.asana.com') || url.include?('asana.com')
      if is_asana
        project_id = extract_asana_project_id(url)
        if project_id
          @one_on_one_link.deep_integration_config ||= {}
          @one_on_one_link.deep_integration_config['asana_project_id'] = project_id
        end
      end
    end
    
    if @one_on_one_link.persisted?
      @one_on_one_link.assign_attributes(one_on_one_link_params)
      if @one_on_one_link.save
        redirect_to organization_company_teammate_one_on_one_link_path(organization, @teammate), 
                    notice: '1:1 link updated successfully.'
      else
        render :show, status: :unprocessable_entity
      end
    else
      @one_on_one_link.assign_attributes(one_on_one_link_params)
      if @one_on_one_link.save
        redirect_to organization_company_teammate_one_on_one_link_path(organization, @teammate), 
                    notice: '1:1 link created successfully.'
      else
        render :show, status: :unprocessable_entity
      end
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
end



