class Organizations::CompanyPreferencesController < Organizations::OrganizationNamespaceBaseController
  before_action :set_company
  after_action :verify_authorized

  def edit
    authorize @company, :customize_company?
    @preferences = load_preferences
  end

  def update
    authorize @company, :customize_company?
    
    if update_preferences
      redirect_to edit_organization_company_preference_path(@organization), notice: 'Company preferences updated successfully.'
    else
      @preferences = load_preferences
      flash.now[:alert] = 'Failed to update company preferences.'
      render :edit, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordInvalid => e
    @preferences = load_preferences
    flash.now[:alert] = "Failed to update company preferences: #{e.message}"
    render :edit, status: :unprocessable_entity
  end

  private

  def set_company
    @company = current_company
  end

  def current_company
    @current_company ||= @organization.root_company || @organization
  end

  def load_preferences
    {
      'prompt' => @company.company_label_preferences.find_by(label_key: 'prompt')&.label_value || ''
    }
  end

  def update_preferences
    success = true
    
    params[:preferences]&.each do |key, value|
      preference = @company.company_label_preferences.find_or_initialize_by(label_key: key.to_s)
      
      if value.present?
        preference.label_value = value
        unless preference.save
          success = false
        end
      else
        # If value is blank, remove the preference (use default)
        preference.destroy if preference.persisted?
      end
    end
    
    success
  end
end
