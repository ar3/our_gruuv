class Organizations::ObservationsController < Organizations::OrganizationNamespaceBaseController
  before_action :set_observation, only: [:show, :edit, :update, :destroy, :post_to_slack]

  def index
    authorize Observation
    # Use ObservationVisibilityQuery for complex visibility logic
    visibility_query = ObservationVisibilityQuery.new(current_person, organization)
    @observations = visibility_query.visible_observations.includes(:observer, :observed_teammates, :observation_ratings)
    @observations = @observations.recent
  end

  def show
    # Show page is only for the observer
    begin
      authorize @observation, :show?
    rescue Pundit::NotAuthorizedError
      date_part = @observation.observed_at.strftime('%Y-%m-%d')
      redirect_to kudos_path(date: date_part, id: @observation.id)
      return
    end
  end

  def new
    authorize Observation
    @observation = organization.observations.build(observer: current_person)
    @form = ObservationForm.new(@observation)
  end

  def create
    authorize Observation
    @observation = organization.observations.build(observer: current_person)
    @form = ObservationForm.new(@observation)
    
    if @form.validate(observation_params)
      # Check if this is step 1 of wizard
      if params[:step] == '2'
        # Store wizard data in session and redirect to step 2
        session[:observation_wizard_data] = wizard_data_from_form(@form)
        redirect_to set_ratings_organization_observation_path(organization, 'new')
      else
        # Direct creation (not wizard)
        if @form.save
          # Handle observees after form saves successfully
          handle_observees(@observation)
          redirect_to organization_observation_path(organization, @observation), 
                      notice: 'Observation was successfully created.'
        else
          # Re-populate the form with submitted values for re-rendering
          render :new, status: :unprocessable_entity
        end
      end
    else
      # Re-populate the form with submitted values for re-rendering
      @form.teammate_ids = params[:observation][:teammate_ids]&.reject(&:blank?) if params[:observation][:teammate_ids].present?
      @form.primary_feeling = params[:observation][:primary_feeling] if params[:observation][:primary_feeling].present?
      @form.secondary_feeling = params[:observation][:secondary_feeling] if params[:observation][:secondary_feeling].present?
      @form.story = params[:observation][:story] if params[:observation][:story].present?
      @form.privacy_level = params[:observation][:privacy_level] if params[:observation][:privacy_level].present?
      @form.observed_at = params[:observation][:observed_at] if params[:observation][:observed_at].present?
      
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    # Edit is only for the observer
    begin
      authorize @observation, :edit?
    rescue Pundit::NotAuthorizedError
      date_part = @observation.observed_at.strftime('%Y-%m-%d')
      redirect_to kudos_path(date: date_part, id: @observation.id)
      return
    end
    
    @form = ObservationForm.new(@observation)
  end

  def update
    # Update is only for the observer
    begin
      authorize @observation, :update?
    rescue Pundit::NotAuthorizedError
      date_part = @observation.observed_at.strftime('%Y-%m-%d')
      redirect_to kudos_path(date: date_part, id: @observation.id)
      return
    end

    @form = ObservationForm.new(@observation)
    
    if @form.validate(observation_params) && @form.save
      redirect_to organization_observation_path(organization, @observation), 
                  notice: 'Observation was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    # Destroy is only for the observer (within 24 hours) or admin
    begin
      authorize @observation, :destroy?
    rescue Pundit::NotAuthorizedError
      date_part = @observation.observed_at.strftime('%Y-%m-%d')
      redirect_to kudos_path(date: date_part, id: @observation.id)
      return
    end

    @observation.soft_delete!
    redirect_to organization_observations_path(organization), 
                notice: 'Observation was successfully deleted.'
  end

  def journal
    authorize Observation
    # Use ObservationVisibilityQuery for complex visibility logic
    visibility_query = ObservationVisibilityQuery.new(current_person, organization)
    @observations = visibility_query.visible_observations.journal.includes(:observer, :observed_teammates, :observation_ratings)
    @observations = @observations.recent
    render :index
  end

  # Wizard Step 2: Ratings & Privacy
  def set_ratings
    authorize Observation
    
    if request.get?
      # Load wizard data from session
      wizard_data = session[:observation_wizard_data]
      if wizard_data.blank?
        redirect_to new_organization_observation_path(organization)
        return
      end
      
      @observation = organization.observations.build(observer: current_person)
      @form = ObservationForm.new(@observation)
      populate_form_from_wizard_data(@form, wizard_data)
      
      # Load available abilities and assignments for selected observees
      teammate_ids = wizard_data['teammate_ids'] || []
      @available_abilities = organization.abilities
      @available_assignments = organization.assignments
      @available_aspirations = organization.aspirations
      
      render :set_ratings
    else
      # POST - process step 2 data
      wizard_data = session[:observation_wizard_data]
      Rails.logger.debug "Session wizard data: #{wizard_data.inspect}"
      Rails.logger.debug "Session keys: #{session.keys.inspect}"
      if wizard_data.blank?
        Rails.logger.debug "Wizard data is blank, redirecting to Step 1"
        redirect_to new_organization_observation_path(organization)
        return
      end
      
      @observation = organization.observations.build(observer: current_person)
      @form = ObservationForm.new(@observation)
      populate_form_from_wizard_data(@form, wizard_data)
      
      if @form.validate(observation_params)
        # Update wizard data with step 2 data
        Rails.logger.debug "Wizard data before update: #{wizard_data.inspect}"
        Rails.logger.debug "observation_params: #{observation_params.inspect}"
        update_wizard_data_from_params(wizard_data, observation_params)
        session[:observation_wizard_data] = wizard_data
        Rails.logger.debug "Wizard data after update: #{wizard_data.inspect}"
        
        if params[:step] == '3'
          redirect_to review_organization_observation_path(organization, 'new')
        else
          redirect_to set_ratings_organization_observation_path(organization, 'new')
        end
      else
        # Re-populate form and show errors
        Rails.logger.debug "Form validation failed: #{@form.errors.full_messages}"
        populate_form_from_wizard_data(@form, wizard_data)
        @form.privacy_level = params[:observation][:privacy_level] if params[:observation][:privacy_level].present?
        @form.observation_ratings_attributes = params[:observation][:observation_ratings_attributes] if params[:observation][:observation_ratings_attributes].present?
        
        teammate_ids = wizard_data['teammate_ids'] || []
        @available_abilities = organization.abilities.where(id: teammate_ids.map(&:to_i))
        @available_assignments = organization.assignments.where(id: teammate_ids.map(&:to_i))
        @available_aspirations = organization.aspirations.where(id: teammate_ids.map(&:to_i))
        
        render :set_ratings, status: :unprocessable_entity
      end
    end
  end

  # Wizard Step 3: Review & Manage
  def review
    authorize Observation
    
    wizard_data = session[:observation_wizard_data]
    if wizard_data.blank?
      redirect_to new_organization_observation_path(organization)
      return
    end
    
    @observation = organization.observations.build(observer: current_person)
    @form = ObservationForm.new(@observation)
    populate_form_from_wizard_data(@form, wizard_data)
    
    # Load observees for notification options
    teammate_ids = wizard_data['teammate_ids'] || []
    @observees_for_notifications = organization.teammates.where(id: teammate_ids.map(&:to_i)).includes(:person)
    
    render :review
  end

  # Final step - create the observation
  def create_observation
    authorize Observation
    
    wizard_data = session[:observation_wizard_data]
    if wizard_data.blank?
      redirect_to new_organization_observation_path(organization)
      return
    end
    
    @observation = organization.observations.build(observer: current_person)
    @form = ObservationForm.new(@observation)
    populate_form_from_wizard_data(@form, wizard_data)
    
    if @form.validate(observation_params) && @form.save
      # Handle observees from wizard data
      handle_observees_from_wizard(@observation, wizard_data)
      
      # Handle ratings
      handle_ratings(@observation, wizard_data)
      
      # Send notifications if requested
      if params[:observation][:send_notifications] == '1'
        notify_teammate_ids = params[:observation][:notify_teammate_ids] || []
        Observations::PostNotificationJob.perform_later(@observation.id, notify_teammate_ids)
      end
      
      # Clear wizard data
      session[:observation_wizard_data] = nil
      
      redirect_to organization_observation_path(organization, @observation), 
                  notice: 'Observation was successfully created.'
    else
      # Re-populate form and show errors
      populate_form_from_wizard_data(@form, wizard_data)
      teammate_ids = wizard_data['teammate_ids'] || []
      @observees_for_notifications = organization.teammates.where(id: teammate_ids.map(&:to_i)).includes(:person)
      
      render :review, status: :unprocessable_entity
    end
  end

  # Slack posting from show page
  def post_to_slack
    authorize @observation, :post_to_slack?
    
    notify_teammate_ids = params[:notify_teammate_ids] || []
    Observations::PostNotificationJob.perform_later(@observation.id, notify_teammate_ids)
    
    redirect_to organization_observation_path(organization, @observation), 
                notice: 'Notifications sent successfully'
  end

  # Quick observation creation from check-ins
  def quick_new
    authorize Observation
    
    # Load or create draft
    if params[:draft_id].present?
      @observation = Observation.find(params[:draft_id])
      authorize @observation, :edit?
      
      # Don't reload - it wipes out fresh data. Just reload associations
      @observation.observation_ratings.reload if @observation.observation_ratings.loaded?
      
      puts "=== LOADING DRAFT #{@observation.id} ==="
      puts "Story: #{@observation.story.inspect}"
      Rails.logger.info "Loading existing draft #{@observation.id}, story: #{@observation.story.inspect}"
    else
      # Create new draft
      @observation = organization.observations.build(observer: current_person)
      
      # Set observees from params
      observee_ids = params[:observee_ids] || []
      observee_ids.each do |teammate_id|
        next if teammate_id.blank?
        @observation.observees.build(teammate_id: teammate_id)
      end
      
      # Set story placeholder
      @observation.story = params[:story] || ''
      @observation.privacy_level = params[:privacy_level] || 'observed_and_managers'
      @observation.observed_at ||= Time.current
      
      @observation.save!
      
      # Add initial rateable if provided
      if params[:rateable_type].present? && params[:rateable_id].present?
        @observation.observation_ratings.create!(
          rateable_type: params[:rateable_type],
          rateable_id: params[:rateable_id]
        )
      end
      
      # Reload to get associations
      @observation.reload
    end
    
    # Ensure observation_ratings are loaded for associations
    @observation.observation_ratings.load if @observation.observation_ratings.loaded?
    
    # Load available rateables
    @assignments = organization.assignments.ordered
    @aspirations = organization.aspirations
    @abilities = organization.abilities.order(:name)
    
    # Store return context
    @return_url = params[:return_url] || organization_observations_path(organization)
    @return_text = params[:return_text] || 'Back'
    
    render layout: 'overlay'
  end

  # Show page for adding assignments to draft
  def add_assignments
    @observation = Observation.find(params[:id])
    authorize @observation, :update?
    
    # Load available assignments
    @assignments = organization.assignments.ordered
    
    # Store return context
    @return_url = params[:return_url] || organization_observations_path(organization)
    @return_text = params[:return_text] || 'Back'
    
    render layout: 'overlay'
  end

  # Add rateables to draft observation
  def add_rateables
    @observation = Observation.find(params[:id])
    authorize @observation, :update?
    
    rateable_type = params[:rateable_type]
    rateable_ids = params[:rateable_ids] || []
    
    Rails.logger.debug "=== Add Rateables ==="
    Rails.logger.debug "Rateable type: #{rateable_type}"
    Rails.logger.debug "Rateable IDs: #{rateable_ids}"
    
    rateable_ids.each do |rateable_id|
      next if rateable_id.blank?
      
      # Check if rating already exists
      existing = @observation.observation_ratings.find_by(
        rateable_type: rateable_type,
        rateable_id: rateable_id
      )
      
      # Only create if it doesn't exist
      unless existing
        rating = @observation.observation_ratings.create!(
          rateable_type: rateable_type,
          rateable_id: rateable_id
        )
        Rails.logger.debug "Created rating: #{rating.id} for #{rateable_type} #{rateable_id}"
      else
        Rails.logger.debug "Rating already exists for #{rateable_type} #{rateable_id}"
      end
    end
    
    @observation.reload
    Rails.logger.debug "Observation now has #{@observation.observation_ratings.count} ratings"
    Rails.logger.debug "Story after reload: #{@observation.story.inspect}"
    
    redirect_url = params[:return_url] || quick_new_organization_observations_path(organization, draft_id: @observation.id)
    redirect_to redirect_url, notice: "Added #{rateable_ids.count} #{rateable_type.downcase}(s)"
  end

  # Update draft observation
  def update_draft
    Rails.logger.info "=== UPDATE DRAFT ACTION CALLED ==="
    Rails.logger.info "Params received: #{params.inspect}"
    
    @observation = Observation.find(params[:id])
    authorize @observation, :update?
    
    Rails.logger.info "Observation found: #{@observation.id}"
    Rails.logger.info "Current story: #{@observation.story.inspect}"
    
    permitted_params = draft_params
    Rails.logger.info "Permitted params: #{permitted_params.inspect}"
    
    if @observation.update(permitted_params)
      @observation.reload
      puts "=== UPDATE SUCCESS === Story: #{@observation.story.inspect}"
      Rails.logger.info "Updated successfully! New story: #{@observation.story.inspect}"
      Rails.logger.info "Story length: #{@observation.story&.length}"
      
      redirect_to quick_new_organization_observations_path(
        organization, 
        draft_id: @observation.id, 
        return_url: params[:return_url], 
        return_text: params[:return_text]
      )
    else
      Rails.logger.error "Failed to update: #{@observation.errors.full_messages.join(', ')}"
      Rails.logger.error "Attempted params: #{permitted_params.inspect}"
      flash[:alert] = "Failed to update: #{@observation.errors.full_messages.join(', ')}"
      @return_url = params[:return_url] || organization_observations_path(organization)
      @return_text = params[:return_text] || 'Back'
      @assignments = organization.assignments.ordered
      @aspirations = organization.aspirations
      @abilities = organization.abilities.order(:name)
      render :quick_new, layout: 'overlay', status: :unprocessable_entity
    end
  end

  # Publish draft observation
  def publish
    @observation = Observation.find(params[:id])
    authorize @observation, :update?
    
    # Update with any new data from publish params
    if params[:observation].present?
      @observation.assign_attributes(draft_params)
    end
    
    # Publish will validate story is present
    if @observation.publish!
      redirect_url = params[:return_url] || organization_observations_path(organization)
      
      # Add show_observations_for param if provided
      if params[:show_observations_for].present?
        redirect_url += "?show_observations_for=#{params[:show_observations_for]}"
      end
      
      # Use status 303 See Other for proper Turbo redirect handling
      redirect_to redirect_url, status: :see_other, notice: 'Observation was successfully published.'
    else
      # Validation failed - redirect back with errors
      @return_url = params[:return_url] || organization_observations_path(organization)
      @return_text = params[:return_text] || 'Back'
      @assignments = organization.assignments.ordered
      @aspirations = organization.aspirations
      @abilities = organization.abilities.order(:name)
      flash[:alert] = "Cannot publish: #{@observation.errors.full_messages.join(', ')}"
      render :quick_new, layout: 'overlay', status: :unprocessable_entity
    end
  end

  private

  def set_observation
    @observation = Observation.find(params[:id])
  end

  def handle_observees(observation)
    # Handle teammate_ids parameter from form
    teammate_ids = params[:observation][:teammate_ids] || []
    teammate_ids.each do |teammate_id|
      next if teammate_id.blank?
      observation.observees.create!(teammate_id: teammate_id)
    end
  end

  def observation_params
    if params[:observation].present?
      params.require(:observation).permit(
        :story, :privacy_level, :primary_feeling, :secondary_feeling, 
        :observed_at, :custom_slug, :send_notifications, teammate_ids: [], notify_teammate_ids: [],
        observees_attributes: [:id, :teammate_id, :_destroy],
        observation_ratings_attributes: {}
      )
    else
      {}
    end
  end

  def wizard_data_from_form(form)
    {
      'story' => form.story,
      'primary_feeling' => form.primary_feeling,
      'secondary_feeling' => form.secondary_feeling,
      'observed_at' => form.observed_at&.to_s,
      'teammate_ids' => form.teammate_ids || []
    }
  end

  def populate_form_from_wizard_data(form, wizard_data)
    form.story = wizard_data['story']
    form.primary_feeling = wizard_data['primary_feeling']
    form.secondary_feeling = wizard_data['secondary_feeling']
    form.observed_at = wizard_data['observed_at'].present? ? Time.parse(wizard_data['observed_at']) : nil
    form.teammate_ids = wizard_data['teammate_ids'] || []
    form.privacy_level = wizard_data['privacy_level']
    
    # Handle observation ratings
    if wizard_data['observation_ratings_attributes'].present?
      # Set the observation_ratings_attributes hash for the view
      form.observation_ratings_attributes = wizard_data['observation_ratings_attributes']
      
      # Also populate the collection for form validation
      form.observation_ratings.clear
      wizard_data['observation_ratings_attributes'].each do |key, rating_attrs|
        next if rating_attrs['rating'].blank?
        form.observation_ratings << ObservationRating.new(
          rateable_type: rating_attrs['rateable_type'],
          rateable_id: rating_attrs['rateable_id'],
          rating: rating_attrs['rating']
        )
      end
    end
  end

  def update_wizard_data_from_params(wizard_data, params)
    return if wizard_data.nil?
    return if params.blank?
    
    wizard_data['privacy_level'] = params[:privacy_level] if params[:privacy_level].present?
    wizard_data['observation_ratings_attributes'] = params[:observation_ratings_attributes] if params[:observation_ratings_attributes].present?
  end

  def handle_observees_from_wizard(observation, wizard_data)
    teammate_ids = wizard_data['teammate_ids'] || []
    teammate_ids.each do |teammate_id|
      observation.observees.create!(teammate_id: teammate_id)
    end
  end

  def handle_ratings(observation, wizard_data)
    return unless wizard_data['observation_ratings_attributes'].present?
    
    wizard_data['observation_ratings_attributes'].each do |key, rating_attrs|
      next if rating_attrs[:_destroy] == '1' || rating_attrs[:rateable_id].blank?
      
      # Check if the rateable object exists
      rateable_class = rating_attrs[:rateable_type].constantize
      rateable_id = rating_attrs[:rateable_id].to_i
      rateable_object = rateable_class.find_by(id: rateable_id)
      
      next if rateable_object.nil?
      
      begin
        observation.observation_ratings.create!(
          rateable_type: rating_attrs[:rateable_type],
          rateable_id: rateable_id,
          rating: rating_attrs[:rating]
        )
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.error "Failed to create rating: #{e.message}"
        raise e
      end
    end
  end

  # Helper methods for views
  helper_method :privacy_level_text, :feelings_display, :rating_icon, :rating_options_for_select

  def rating_options_for_select(selected_value = nil)
    [
      ['Select rating...', ''],
      ['⭐ Strongly Agree (Exceptional)', 'strongly_agree'],
      ['👍 Agree (Good)', 'agree'],
      ['👁️‍🗨️ N/A', 'na'],
      ['👎 Disagree (Opportunity)', 'disagree'],
      ['⭕ Strongly Disagree (Major Concern)', 'strongly_disagree']
    ]
  end


  def privacy_level_text(privacy_level)
    case privacy_level
    when 'observer_only'
      '🔒 Just for me (Journal)'
    when 'observed_only'
      '👤 Just for them'
    when 'managers_only'
      '👔 For their managers'
    when 'observed_and_managers'
      '👥 For them and their managers'
    when 'public_observation'
      '🌍 Public to organization'
    else
      privacy_level&.humanize || 'Not set'
    end
  end

  def feelings_display(primary_feeling, secondary_feeling = nil)
    feelings = []
    if primary_feeling.present?
      feeling_data = Feelings.hydrate(primary_feeling)
      feelings << "#{feeling_data[:display]} #{feeling_data[:discrete_feeling].to_s.humanize}" if feeling_data
    end
    if secondary_feeling.present?
      feeling_data = Feelings.hydrate(secondary_feeling)
      feelings << "#{feeling_data[:display]} #{feeling_data[:discrete_feeling].to_s.humanize}" if feeling_data
    end
    feelings.join(' + ')
  end

  def rating_icon(rating)
    case rating
    when 'strongly_agree'
      '⭐'
    when 'agree'
      '👍'
    when 'na'
      '👁️‍🗨️'
    when 'disagree'
      '👎'
    when 'strongly_disagree'
      '⭕'
    else
      '❓'
    end
  end

  def draft_params
    params.require(:observation).permit(
      :story, :primary_feeling, :secondary_feeling, :privacy_level,
      observation_ratings_attributes: [:id, :rateable_type, :rateable_id, :rating, :_destroy]
    )
  end
end
