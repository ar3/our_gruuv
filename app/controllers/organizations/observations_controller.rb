class Organizations::ObservationsController < Organizations::OrganizationNamespaceBaseController
  before_action :set_observation, only: [:show, :edit, :update, :destroy, :post_to_slack]

  def index
    authorize Observation
    
    # Use ObservationsQuery for filtering and sorting
    query = ObservationsQuery.new(organization, params, current_person: current_person)
    
    # Get observations with filters (but not sorting that uses group/join)
    filtered_observations = base_filtered(query)
    
    # Count before applying complex sorts (like ratings_count which uses group)
    total_count = if params[:sort] == 'ratings_count_desc'
      # For ratings count sort, we need to count distinct observations
      filtered_observations.left_joins(:observation_ratings)
                          .group('observations.id')
                          .count
                          .length
    else
      filtered_observations.count
    end
    
    # Apply sorting (may add joins/group)
    sorted_observations = query.call
    
    # Eager load associations needed for the view
    sorted_observations = sorted_observations.includes(:observer, { observed_teammates: :person }, :observation_ratings, :notifications)
    
    # Paginate using Pagy (25 items per page, similar to employees controller)
    @pagy = Pagy.new(count: total_count, page: params[:page] || 1, items: 25)
    @observations = sorted_observations.limit(@pagy.items).offset(@pagy.offset)
    
    # Manually preload polymorphic rateable associations to avoid N+1 queries
    preload_rateables
    
    # Calculate spotlight statistics from all observations (not filtered, not paginated)
    # Need to re-run query without sorting joins to avoid group issues
    all_observations_query = ObservationsQuery.new(organization, params.except(:sort), current_person: current_person)
    all_observations = all_observations_query.call
    @spotlight_stats = calculate_spotlight_stats(all_observations)
    
    # Store current filter/sort/view/spotlight state for view
    @current_filters = query.current_filters
    @current_sort = query.current_sort
    @current_view = query.current_view
    @current_spotlight = query.current_spotlight
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
    
    # Load or create draft
    if params[:draft_id].present?
      @observation = Observation.find(params[:draft_id])
      authorize @observation, :edit?
      
      # Don't reload - it wipes out fresh data. Just reload associations
      @observation.observation_ratings.reload if @observation.observation_ratings.loaded?
      
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
      
      # Set defaults (not saved yet - will be saved when user clicks "Add Assignments" or "Publish")
      @observation.story = params[:story] || ''
      @observation.privacy_level = params[:privacy_level] || 'observed_and_managers'
      @observation.observed_at ||= Time.current
      
      # Add initial rateable if provided (build in memory, not saved)
      # Need to load the rateable so it's available even when observation isn't saved
      if params[:rateable_type].present? && params[:rateable_id].present?
        rateable = params[:rateable_type].constantize.find(params[:rateable_id])
        rating = @observation.observation_ratings.build(
          rateable_type: params[:rateable_type],
          rateable_id: params[:rateable_id]
        )
        # Pre-load the rateable association so it's available for @observation.assignments
        rating.rateable = rateable
      end
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
      @form.publishing = true
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

  # Quick observation creation from check-ins (backward compatibility - redirects to new)
  def quick_new
    redirect_to new_organization_observation_path(
      organization,
      draft_id: params[:draft_id],
      observee_ids: params[:observee_ids],
      rateable_type: params[:rateable_type],
      rateable_id: params[:rateable_id],
      story: params[:story],
      privacy_level: params[:privacy_level],
      return_url: params[:return_url],
      return_text: params[:return_text]
    )
  end

  # Save draft and navigate to add assignments page
  def save_and_add_assignments
    @observation = Observation.find(params[:id])
    authorize @observation, :update?
    
    # Save current form data as draft
    if @observation.update(draft_params)
      redirect_to add_assignments_organization_observation_path(
        organization, 
        @observation,
        return_url: params[:return_url] || new_organization_observation_path(organization, draft_id: @observation.id),
        return_text: params[:return_text] || 'Draft'
      )
    else
      # If save fails, redirect back with errors
      flash[:alert] = "Failed to save: #{@observation.errors.full_messages.join(', ')}"
      redirect_to new_organization_observation_path(
        organization,
        draft_id: @observation.id,
        return_url: params[:return_url],
        return_text: params[:return_text]
      )
    end
  end

  # Show page for adding assignments to draft
  def add_assignments
    @observation = Observation.find(params[:id])
    authorize @observation, :update?
    
    # Load available assignments
    @assignments = organization.assignments.ordered
    
    # Store return context
    @return_url = params[:return_url] || new_organization_observation_path(organization, draft_id: @observation.id)
    @return_text = params[:return_text] || 'Back'
    
    render layout: 'overlay'
  end

  # Show page for adding aspirations to draft
  def add_aspirations
    @observation = Observation.find(params[:id])
    authorize @observation, :update?
    
    @aspirations = organization.aspirations
    
    @return_url = params[:return_url] || new_organization_observation_path(organization, draft_id: @observation.id)
    @return_text = params[:return_text] || 'Back'
    
    render layout: 'overlay'
  end

  # Show page for adding abilities to draft
  def add_abilities
    @observation = Observation.find(params[:id])
    authorize @observation, :update?
    
    @abilities = organization.abilities.order(:name)
    
    @return_url = params[:return_url] || new_organization_observation_path(organization, draft_id: @observation.id)
    @return_text = params[:return_text] || 'Back'
    
    render layout: 'overlay'
  end

  # Show page (GET) for adding observees to draft
  # POST handling lives below in the same action (see request.post? branch)

  # Add rateables to draft observation
  def add_rateables
    @observation = Observation.find(params[:id])
    authorize @observation, :update?
    
    # Save any form data from add_assignments page first
    if params[:observation].present?
      @observation.update(draft_params)
    end
    
    rateable_type = params[:rateable_type]
    rateable_ids = params[:rateable_ids] || []
    
    # Reload to ensure we have fresh association data before checking for duplicates
    @observation.reload
    
    rateable_ids.each do |rateable_id|
      next if rateable_id.blank?
      
      # Check if rating already exists (reload ensures this check is accurate)
      existing = @observation.observation_ratings.find_by(
        rateable_type: rateable_type,
        rateable_id: rateable_id
      )
      
      # Only create if it doesn't exist - skip silently if already present
      unless existing
        @observation.observation_ratings.create!(
          rateable_type: rateable_type,
          rateable_id: rateable_id
        )
      end
    end
    
    @observation.reload
    
    # Preserve return_url and return_text when redirecting back
    redirect_url = params[:return_url] || new_organization_observation_path(organization, draft_id: @observation.id)
    if params[:return_url].present? || params[:return_text].present?
      redirect_url = new_organization_observation_path(
        organization,
        draft_id: @observation.id,
        return_url: params[:return_url],
        return_text: params[:return_text]
      )
    end
    redirect_to redirect_url, notice: "Added #{rateable_ids.count} #{rateable_type.downcase}(s)"
  end

  # Manage observees for draft observation
  def manage_observees
    @observation = Observation.find(params[:id])
    authorize @observation, :update?
    
    if request.patch?
      teammate_ids = params[:teammate_ids] || []
      teammate_ids = teammate_ids.reject(&:blank?).map(&:to_i)
      
      # Get current observee teammate IDs
      current_observee_ids = @observation.observees.pluck(:teammate_id)
      
      # Determine which observees to add and which to remove
      observees_to_add = teammate_ids - current_observee_ids
      observees_to_remove = current_observee_ids - teammate_ids
      
      # Build observees_attributes for nested attributes
      observees_attributes = {}
      index = 0
      
      # Add existing observees that should remain (with id, no _destroy)
      @observation.observees.each do |observee|
        if teammate_ids.include?(observee.teammate_id)
          observees_attributes[index.to_s] = {
            id: observee.id,
            teammate_id: observee.teammate_id
          }
          index += 1
        end
      end
      
      # Mark observees for removal (with id and _destroy)
      @observation.observees.each do |observee|
        if observees_to_remove.include?(observee.teammate_id)
          observees_attributes[index.to_s] = {
            id: observee.id,
            _destroy: '1'
          }
          index += 1
        end
      end
      
      # Add new observees (without id)
      observees_to_add.each do |teammate_id|
        observees_attributes[index.to_s] = {
          teammate_id: teammate_id
        }
        index += 1
      end
      
      # Update using nested attributes
      if @observation.update(observees_attributes: observees_attributes)
        added_count = observees_to_add.count
        removed_count = observees_to_remove.count
        
        if added_count > 0 && removed_count > 0
          notice = "Added #{added_count} observee(s) and removed #{removed_count} observee(s)"
        elsif added_count > 0
          notice = "Added #{added_count} observee(s)"
        elsif removed_count > 0
          notice = "Removed #{removed_count} observee(s)"
        else
          notice = "No changes made"
        end
        
        redirect_url = params[:return_url] || new_organization_observation_path(organization, draft_id: @observation.id)
        if params[:return_url].present? || params[:return_text].present?
          redirect_url = new_organization_observation_path(
            organization,
            draft_id: @observation.id,
            return_url: params[:return_url],
            return_text: params[:return_text]
          )
        end
        redirect_to redirect_url, notice: notice
      else
        flash[:alert] = "Failed to update observees: #{@observation.errors.full_messages.join(', ')}"
        @teammates = organization.teammates.includes(:person)
        @return_url = params[:return_url] || new_organization_observation_path(organization, draft_id: @observation.id)
        @return_text = params[:return_text] || 'Back'
        render :manage_observees, layout: 'overlay', status: :unprocessable_entity
      end
    else
      # GET - render picker
      @teammates = organization.teammates.includes(:person)
      @return_url = params[:return_url] || new_organization_observation_path(organization, draft_id: @observation.id)
      @return_text = params[:return_text] || 'Back'
      render layout: 'overlay'
    end
  end

  # Update draft observation
  def update_draft
    # Handle new observations (id = 'new')
    if params[:id] == 'new' || params[:id].to_s == 'new'
      # Create new observation - build from params and save
      @observation = organization.observations.build(observer: current_person)
      
      # Set observees from params if provided
      observee_ids = params[:observee_ids] || []
      observee_ids = [observee_ids] unless observee_ids.is_a?(Array)
      observee_ids.each do |teammate_id|
        next if teammate_id.blank?
        @observation.observees.build(teammate_id: teammate_id)
      end
      
      # Use Reform to handle nested attributes properly and avoid duplicates
      permitted_params = draft_params
      @form = ObservationForm.new(@observation)
      if @form.validate(permitted_params)
        @form.save
        @observation.observed_at ||= Time.current
        @observation.save! if @observation.changed? || @observation.new_record?
        authorize @observation, :update?
      else
        flash[:alert] = "Failed to save: #{@form.errors.full_messages.join(', ')}"
        @return_url = params[:return_url] || organization_observations_path(organization)
        @return_text = params[:return_text] || 'Back'
        @assignments = organization.assignments.ordered
        @aspirations = organization.aspirations
        @abilities = organization.abilities.order(:name)
        render :new, layout: 'overlay', status: :unprocessable_entity
        return
      end
    else
      @observation = Observation.find(params[:id])
      authorize @observation, :update?
    end
    
    permitted_params = draft_params
    # Note: We no longer strip out observation_ratings_attributes for save-and-add flows.
    # ObservationForm#save handles duplicate prevention correctly by checking for existing
    # ratings before creating new ones, so ratings will be preserved when adding observees,
    # abilities, or aspirations.
    
    # Use Reform in draft mode (no story requirement)
    @form = ObservationForm.new(@observation)
    @form.publishing = false
    saved = @form.validate(permitted_params) && @form.save
    
    if saved
      # Check if we should save and navigate to an add-* picker
      if params[:save_and_add_assignments].present?
        redirect_to add_assignments_organization_observation_path(
          organization, 
          @observation,
          return_url: params[:return_url] || new_organization_observation_path(organization, draft_id: @observation.id, return_url: params[:return_url], return_text: params[:return_text]),
          return_text: params[:return_text] || 'Observation'
        )
      elsif params[:save_and_add_aspirations].present?
        redirect_to add_aspirations_organization_observation_path(
          organization,
          @observation,
          return_url: params[:return_url] || new_organization_observation_path(organization, draft_id: @observation.id, return_url: params[:return_url], return_text: params[:return_text]),
          return_text: params[:return_text] || 'Observation'
        )
      elsif params[:save_and_add_abilities].present?
        redirect_to add_abilities_organization_observation_path(
          organization,
          @observation,
          return_url: params[:return_url] || new_organization_observation_path(organization, draft_id: @observation.id, return_url: params[:return_url], return_text: params[:return_text]),
          return_text: params[:return_text] || 'Observation'
        )
      elsif params[:save_and_manage_observees].present?
        redirect_to manage_observees_organization_observation_path(
          organization,
          @observation,
          return_url: params[:return_url] || new_organization_observation_path(organization, draft_id: @observation.id, return_url: params[:return_url], return_text: params[:return_text]),
          return_text: params[:return_text] || 'Observation'
        )
      else
        redirect_to new_organization_observation_path(
          organization, 
          draft_id: @observation.id, 
          return_url: params[:return_url], 
          return_text: params[:return_text]
        )
      end
    else
      Rails.logger.error "Failed to update: #{@observation.errors.full_messages.join(', ')}"
      Rails.logger.error "Attempted params: #{permitted_params.inspect}"
      flash[:alert] = "Failed to update: #{@observation.errors.full_messages.join(', ')}"
      @return_url = params[:return_url] || organization_observations_path(organization)
      @return_text = params[:return_text] || 'Back'
      @assignments = organization.assignments.ordered
      @aspirations = organization.aspirations
      @abilities = organization.abilities.order(:name)
      render :new, layout: 'overlay', status: :unprocessable_entity
    end
  end

  # Cancel and optionally save draft if story has content
  def cancel
    # Handle both persisted and new observations
    if params[:id] == 'new' || params[:id].to_s == 'new'
      # New observation - check if story has content
      story = params[:observation] && params[:observation][:story] ? params[:observation][:story] : params[:story]
      
      if story.present? && story.strip.present?
        # Story has content - save as draft before canceling
        @observation = organization.observations.build(observer: current_person)
        
        # Set observees from params if provided
        observee_ids = params[:observee_ids] || []
        observee_ids = [observee_ids] unless observee_ids.is_a?(Array)
        observee_ids.each do |teammate_id|
          next if teammate_id.blank?
          @observation.observees.build(teammate_id: teammate_id)
        end
        
        @observation.assign_attributes(draft_params)
        @observation.observed_at ||= Time.current
        @observation.save!
      end
    else
      # Existing observation - update with any form data if story has content
      @observation = Observation.find(params[:id])
      authorize @observation, :update?
      
      story = params[:observation] && params[:observation][:story] ? params[:observation][:story] : @observation.story
      
      if story.present? && story.strip.present?
        # Update observation with form data
        @observation.update(draft_params)
      end
    end
    
    # Always redirect to return_url (even if no draft was saved)
    redirect_url = params[:return_url] || organization_observations_path(organization)
    redirect_to redirect_url
  end

  # Publish draft observation
  def publish
    # Handle both persisted and new observations
    if params[:id] == 'new' || params[:id].to_s == 'new'
      # New observation - create and publish in one step
      @observation = organization.observations.build(observer: current_person)
      
      # Set observees from params if provided
      observee_ids = params[:observee_ids] || []
      observee_ids = [observee_ids] unless observee_ids.is_a?(Array)
      observee_ids.each do |teammate_id|
        next if teammate_id.blank?
        @observation.observees.build(teammate_id: teammate_id)
      end
      
      @observation.observed_at ||= Time.current
      
      permitted = draft_params
      Rails.logger.debug "=== PUBLISH DEBUG START ==="
      Rails.logger.debug "draft_params keys: #{permitted.keys.inspect}"
      Rails.logger.debug "draft_params observation_ratings_attributes present?: #{permitted[:observation_ratings_attributes].present?}"
      Rails.logger.debug "draft_params observation_ratings_attributes: #{permitted[:observation_ratings_attributes].inspect}"
      Rails.logger.debug "draft_params full: #{permitted.inspect}"
      Rails.logger.debug "params[:observation] raw: #{params[:observation].inspect}"
      
      # Use Reform form to handle nested attributes properly
      @form = ObservationForm.new(@observation)
      Rails.logger.debug "Form observation_ratings before validate: #{@form.observation_ratings.map { |r| "#{r.rateable_type}:#{r.rateable_id}=>#{r.rating}" }.inspect}"
      
      if @form.validate(permitted)
        Rails.logger.debug "Form validated successfully"
        @form.save
        Rails.logger.debug "Form saved. Model observation_ratings count: #{@observation.observation_ratings.reload.count}"
        Rails.logger.debug "Model observation_ratings: #{@observation.observation_ratings.map { |r| "#{r.rateable_type}:#{r.rateable_id}=>#{r.rating}" }.inspect}"
        authorize @observation, :update?
      else
        Rails.logger.error "Publish validation failed: #{@form.errors.full_messages}"
        @return_url = params[:return_url] || organization_observations_path(organization)
        @return_text = params[:return_text] || 'Back'
        @assignments = organization.assignments.ordered
        @aspirations = organization.aspirations
        @abilities = organization.abilities.order(:name)
        flash[:alert] = "Cannot publish: #{@form.errors.full_messages.join(', ')}"
        render :new, layout: 'overlay', status: :unprocessable_entity
        return
      end
    else
      @observation = Observation.find(params[:id])
      authorize @observation, :update?

      if params[:observation].present?
        # Use Reform form to handle nested attributes properly
        @form = ObservationForm.new(@observation)
        @form.publishing = true
        if @form.validate(draft_params)
          @form.save
        else
          Rails.logger.error "Publish validation failed: #{@form.errors.full_messages}"
          @return_url = params[:return_url] || organization_observations_path(organization)
          @return_text = params[:return_text] || 'Back'
          @assignments = organization.assignments.ordered
          @aspirations = organization.aspirations
          @abilities = organization.abilities.order(:name)
          flash[:alert] = "Cannot publish: #{@form.errors.full_messages.join(', ')}"
          render :new, layout: 'overlay', status: :unprocessable_entity
          return
        end
      end
    end
    
    # Publish will validate story is present (required for published observations)
    begin
      @observation.publish!
      # If return_url is provided, use it (from form/new page)
      # Otherwise, redirect to show page (publish from show page)
      redirect_url = params[:return_url] || organization_observation_path(organization, @observation)
      
      # Add show_observations_for param if provided (only for index redirects)
      if params[:return_url].present? && params[:show_observations_for].present?
        redirect_url += "?show_observations_for=#{params[:show_observations_for]}"
      end
      
      redirect_to redirect_url, notice: 'Observation was successfully published.'
    rescue ActiveRecord::RecordInvalid => e
      # Validation failed - handle based on context
      if params[:return_url].present?
        # From form/new page - render form with errors
        @return_url = params[:return_url] || organization_observations_path(organization)
        @return_text = params[:return_text] || 'Back'
        @assignments = organization.assignments.ordered
        @aspirations = organization.aspirations
        @abilities = organization.abilities.order(:name)
        flash[:alert] = "Cannot publish: #{@observation.errors.full_messages.join(', ')}"
        render :new, layout: 'overlay', status: :unprocessable_entity
      else
        # From show page - redirect back with error
        redirect_to organization_observation_path(organization, @observation),
                    alert: "Cannot publish: #{@observation.errors.full_messages.join(', ')}"
      end
    end
  end

  private

  def base_filtered(query)
    # Get filtered observations without sorting (to get accurate count)
    observations = query.base_scope
    observations = query.filter_by_privacy_levels(observations)
    observations = query.filter_by_timeframe(observations)
    observations
  end

  def calculate_spotlight_stats(observations)
    # Ensure we're working with an ActiveRecord relation for proper queries
    if observations.is_a?(Array)
      observation_ids = observations.map(&:id)
      observations_relation = Observation.where(id: observation_ids)
    else
      observations_relation = observations
    end

    case @current_spotlight
    when 'my_journal'
      {
        total_observations: observations.where(privacy_level: :observer_only, observer: current_person).count,
        this_week: observations.where(privacy_level: :observer_only, observer: current_person, observed_at: 1.week.ago..).count,
        this_month: observations.where(privacy_level: :observer_only, observer: current_person, observed_at: 1.month.ago..).count,
        with_ratings: observations_relation.where(privacy_level: :observer_only, observer: current_person).joins(:observation_ratings).distinct.count
      }
    when 'team_wins'
      {
        total_public: observations.where(privacy_level: :public_observation).count,
        this_week: observations.where(privacy_level: :public_observation, observed_at: 1.week.ago..).count,
        this_month: observations.where(privacy_level: :public_observation, observed_at: 1.month.ago..).count,
        with_ratings: observations_relation.where(privacy_level: :public_observation).joins(:observation_ratings).distinct.count,
        positive_ratings: observations_relation.where(privacy_level: :public_observation)
                                                .joins(:observation_ratings)
                                                .where(observation_ratings: { rating: [:strongly_agree, :agree] })
                                                .distinct.count
      }
    when 'this_week'
      {
        total_this_week: observations.where(observed_at: 1.week.ago..).count,
        journal_entries: observations.where(privacy_level: :observer_only, observed_at: 1.week.ago..).count,
        public_observations: observations.where(privacy_level: :public_observation, observed_at: 1.week.ago..).count,
        with_ratings: observations_relation.where(observed_at: 1.week.ago..).joins(:observation_ratings).distinct.count
      }
    else # 'overview' or default
      {
        total_observations: observations.count,
        this_week: observations.where(observed_at: 1.week.ago..).count,
        journal_entries: observations.where(privacy_level: :observer_only).count,
        public_observations: observations.where(privacy_level: :public_observation).count,
        with_ratings: observations_relation.joins(:observation_ratings).distinct.count
      }
    end
  end

  def preload_rateables
    # Collect all rateable ids grouped by type
    rating_ids_by_type = @observations.flat_map(&:observation_ratings).group_by(&:rateable_type)
    
    # Preload each type separately to avoid N+1 queries on polymorphic association
    rating_ids_by_type.each do |rateable_type, ratings|
      ids = ratings.map(&:rateable_id).uniq
      next if ids.empty?
      
      case rateable_type
      when 'Assignment'
        Assignment.where(id: ids).load
      when 'Ability'
        Ability.where(id: ids).load
      when 'Aspiration'
        Aspiration.where(id: ids).load
      end
    end
  end

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
        :observed_at, :custom_slug, :send_notifications, :publishing,
        teammate_ids: [], notify_teammate_ids: [],
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
    permitted = params.require(:observation).permit(
      :story, :primary_feeling, :secondary_feeling, :privacy_level,
      observation_ratings_attributes: {}
    )
    
    # Manually permit the nested observation_ratings_attributes hash with string keys like "assignment_1"
    # Rails strong params doesn't handle dynamic keys well, so we need to iterate
    if params[:observation][:observation_ratings_attributes].present?
      ratings_attrs = {}
      params[:observation][:observation_ratings_attributes].each do |key, attrs|
        ratings_attrs[key] = attrs.permit(:id, :rateable_type, :rateable_id, :rating, :_destroy) if attrs.present?
      end
      permitted[:observation_ratings_attributes] = ratings_attrs
    end
    
    # Convert empty strings to nil for optional fields
    permitted[:secondary_feeling] = nil if permitted[:secondary_feeling].blank?
    permitted[:primary_feeling] = nil if permitted[:primary_feeling].blank?
    
    permitted
  end
end
