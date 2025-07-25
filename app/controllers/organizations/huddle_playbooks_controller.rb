class Organizations::HuddlePlaybooksController < ApplicationController
  before_action :require_authentication
  before_action :set_organization
  before_action :set_huddle_playbook, only: [:edit, :update, :destroy]
  
  def index
    @huddle_playbooks = @organization.huddle_playbooks.order(:special_session_name)
  end
  
  def new
    @huddle_playbook = @organization.huddle_playbooks.build
  end
  
  def create
    @huddle_playbook = @organization.huddle_playbooks.build(huddle_playbook_params)
    
    if @huddle_playbook.save
      redirect_to organization_huddle_playbooks_path(@organization), notice: 'Huddle playbook was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end
  
  def edit
  end
  
  def update
    if @huddle_playbook.update(huddle_playbook_params)
      redirect_to organization_huddle_playbooks_path(@organization), notice: 'Huddle playbook was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    @huddle_playbook.destroy
    redirect_to organization_huddle_playbooks_path(@organization), notice: 'Huddle playbook was successfully deleted.'
  end
  
  private
  
  def set_organization
    @organization = Organization.find(params[:organization_id])
  end
  
  def set_huddle_playbook
    @huddle_playbook = @organization.huddle_playbooks.find(params[:id])
  end
  
  def huddle_playbook_params
          params.require(:huddle_playbook).permit(:special_session_name, :slack_channel)
  end
  
  def require_authentication
    unless current_person
      redirect_to root_path, alert: 'Please log in to access huddle playbooks.'
    end
  end
end
