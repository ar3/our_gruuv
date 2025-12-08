class Organizations::OneOnOneLinksController < Organizations::OrganizationNamespaceBaseController
  before_action :authenticate_person!
  before_action :set_person
  before_action :set_teammate
  before_action :set_one_on_one_link

  def show
    authorize @one_on_one_link
  end

  def update
    authorize @one_on_one_link
    
    if @one_on_one_link.persisted?
      if @one_on_one_link.update(one_on_one_link_params)
        redirect_to organization_person_one_on_one_link_path(@organization, @person), 
                    notice: '1:1 link updated successfully.'
      else
        render :show, status: :unprocessable_entity
      end
    else
      @one_on_one_link.assign_attributes(one_on_one_link_params)
      if @one_on_one_link.save
        redirect_to organization_person_one_on_one_link_path(@organization, @person), 
                    notice: '1:1 link created successfully.'
      else
        render :show, status: :unprocessable_entity
      end
    end
  end

  private

  def set_person
    @person = Person.find(params[:person_id])
  end

  def set_teammate
    @teammate = @person.teammates.find_by(organization: @organization)
    unless @teammate
      redirect_to organization_person_path(@organization, @person), 
                  alert: 'Teammate not found for this organization.'
    end
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

