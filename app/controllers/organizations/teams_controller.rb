class Organizations::TeamsController < Organizations::OrganizationNamespaceBaseController
  before_action :require_authentication
  before_action :set_team, only: [:show, :edit, :update, :archive, :manage_members, :update_members]

  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

  def index
    authorize @organization, :show?
    @teams = Team.for_company(@organization).active.ordered.includes(:team_members, :company_teammates)
  end

  def show
    authorize @team, :show?
    @team_members = @team.team_members.includes(company_teammate: :person).order('people.last_name, people.first_name')
    @team.huddles.preload(:huddle_participants).load
  end

  def new
    @team = Team.new(company: @organization)
    authorize @team, :create?
  end

  def create
    @team = Team.new(team_params)
    @team.company = @organization
    authorize @team, :create?

    if @team.save
      redirect_to organization_teams_path(@organization), notice: 'Team was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @team, :update?
  end

  def update
    authorize @team, :update?

    if @team.update(team_params)
      redirect_to organization_team_path(@organization, @team), notice: 'Team was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def archive
    authorize @team, :archive?

    @team.soft_delete!
    redirect_to organization_teams_path(@organization), notice: 'Team was successfully archived.'
  end

  def manage_members
    authorize @team, :update?
    
    # Get all active employees from the company
    @teammates = @organization.teammates
      .joins(:person)
      .includes(:person)
      .merge(CompanyTeammate.employed)
      .order(Arel.sql('people.last_name, COALESCE(people.preferred_name, people.first_name)'))
    
    # Preload member IDs to avoid N+1 (exists? per teammate in view)
    @member_teammate_ids = @team.team_members.pluck(:company_teammate_id).to_set
    
    @return_url = params[:return_url] || organization_team_path(@organization, @team)
    @return_text = params[:return_text] || 'Back'
  end

  def update_members
    authorize @team, :update?
    
    teammate_ids = params[:teammate_ids] || []
    teammate_ids = teammate_ids.reject(&:blank?).map(&:to_i)
    
    # Get current member teammate IDs
    current_member_ids = @team.team_members.pluck(:company_teammate_id)
    
    # Determine which members to add and which to remove
    members_to_add = teammate_ids - current_member_ids
    members_to_remove = current_member_ids - teammate_ids
    
    # Remove members that are no longer selected
    removed_count = @team.team_members.where(company_teammate_id: members_to_remove).destroy_all.count
    
    # Add new members
    added_count = 0
    members_to_add.each do |teammate_id|
      unless @team.team_members.exists?(company_teammate_id: teammate_id)
        @team.team_members.create!(company_teammate_id: teammate_id)
        added_count += 1
      end
    end
    
    # Build success message
    notice = if added_count > 0 && removed_count > 0
               "Added #{added_count} member(s) and removed #{removed_count} member(s)"
             elsif added_count > 0
               "Added #{added_count} member(s)"
             elsif removed_count > 0
               "Removed #{removed_count} member(s)"
             else
               "No changes made"
             end
    
    redirect_to organization_team_path(@organization, @team), notice: notice
  end

  private

  def set_team
    # Extract ID from params (handles both "123" and "123-name" formats)
    id_from_params = params[:id].to_s.split('-').first.to_i
    return if id_from_params.zero?

    @team = Team.for_company(@organization).active.find(id_from_params)
  rescue ActiveRecord::RecordNotFound
    raise ActiveRecord::RecordNotFound
  end

  def team_params
    params.require(:team).permit(:name)
  end

  def require_authentication
    unless current_person
      redirect_to root_path, alert: 'Please log in to access teams.'
    end
  end

  def record_not_found
    render file: Rails.root.join('public', '404.html'), status: :not_found, layout: false
  end
end
