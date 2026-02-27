class Organizations::ObservationsController < Organizations::OrganizationNamespaceBaseController
  before_action :set_observation, only: [:show, :destroy, :restore, :post_to_slack, :share_publicly, :share_privately, :award_kudos, :award_celebratory_kudos]
  

  def index
    authorize company, :view_observations?
    
    # Handle preset application (if preset is selected and no discrete options changed)
    apply_preset_if_selected
    
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
    
    # Store current filter/sort/view/spotlight state for view (needed before calculate_spotlight_stats)
    @current_filters = query.current_filters
    @current_sort = query.current_sort
    @current_view = query.current_view
    @current_spotlight = query.current_spotlight

    # Load teammate for "involving" filter pill when that filter is active
    @involving_teammate = if params[:involving_teammate_id].present?
      CompanyTeammate.where(organization: organization).find_by(id: params[:involving_teammate_id])
    end

    # Load teammate for "observations by" / "observations about" filter pills
    @observer_teammate = if params[:observer_id].present?
      CompanyTeammate.where(organization: organization).find_by(person_id: params[:observer_id])
    end
    observee_ids = Array(params[:observee_ids]).reject(&:blank?)
    @observee_teammate = if observee_ids.one?
      CompanyTeammate.where(organization: organization).find_by(id: observee_ids.first)
    end

    # Calculate spotlight statistics from all observations (not filtered, not paginated)
    # Need to re-run query without sorting joins to avoid group issues
    all_observations_query = ObservationsQuery.new(organization, params.except(:sort), current_person: current_person)
    all_observations = all_observations_query.call
    @spotlight_stats = calculate_spotlight_stats(all_observations)
    
    # Store return context for back link
    @return_url = params[:return_url]
    @return_text = params[:return_text]
  end

  def select_type
    authorize Observation, :create?
    
    # Store return context if provided
    @return_url = params[:return_url]
    @return_text = params[:return_text]
    
    render layout: 'overlay'
  end

  def customize_view
    authorize company, :view_observations?
    
    # Load current state from params
    query = ObservationsQuery.new(organization, params, current_person: current_person)
    
    @current_filters = query.current_filters
    @current_sort = query.current_sort
    @current_view = query.current_view
    @current_spotlight = query.current_spotlight
    
    # Preserve current params for return URL
    return_params = params.except(:controller, :action, :page).permit!.to_h
    @return_url = organization_observations_path(@organization, return_params)
    @return_text = "Back to Culture of Feedback and Recognition"
    
    render layout: 'overlay'
  end

  def update_view
    authorize company, :view_observations?
    
    # Build redirect URL with view customization params
    if params[:preset].present?
      # When preset is selected, only include preset-defined params
      preset_params = preset_to_params(params[:preset])
      redirect_params = {}
      
      if preset_params
        # Use preset params directly - Rails path helpers handle arrays automatically
        redirect_params = preset_params.dup
        
        # Handle special case for timeframe: 'between' - preserve date params if preset includes between
        if preset_params[:timeframe] == 'between'
          redirect_params[:timeframe_start_date] = params[:timeframe_start_date] if params[:timeframe_start_date].present?
          redirect_params[:timeframe_end_date] = params[:timeframe_end_date] if params[:timeframe_end_date].present?
        end
      end
    else
      # When no preset, include all params except Rails internal ones
      redirect_params = params.except(:controller, :action, :authenticity_token, :_method, :commit).permit!.to_h
      # Permit timeframe_start_date and timeframe_end_date for between timeframe
      if redirect_params[:timeframe] == 'between'
        redirect_params[:timeframe_start_date] = params[:timeframe_start_date] if params[:timeframe_start_date].present?
        redirect_params[:timeframe_end_date] = params[:timeframe_end_date] if params[:timeframe_end_date].present?
      end
    end
    
    redirect_to organization_observations_path(@organization, redirect_params)
  end

  def filtered_observations
    # Initialize observations before authorization to prevent nil errors on redirect
    @observations = Observation.none
    
    authorize company, :view_observations?
    
    # Extract filter parameters
    @rateable_type = params[:rateable_type]
    @rateable_id = params[:rateable_id]
    @observee_ids = Array(params[:observee_ids]).reject(&:blank?)
    
    # Parse dates from URL parameters (Rails converts Time objects to ISO8601 strings in URLs)
    @start_date = if params[:start_date].present?
      begin
        Time.parse(params[:start_date])
      rescue ArgumentError
        nil
      end
    else
      nil
    end
    
    @end_date = if params[:end_date].present?
      begin
        Time.parse(params[:end_date])
      rescue ArgumentError
        nil
      end
    else
      nil
    end
    
    # Start with visible observations using ObservationVisibilityQuery
    visibility_query = ObservationVisibilityQuery.new(current_person, organization)
    observations = visibility_query.visible_observations
    
    # For filtered_observations, exclude soft-deleted observations (even observer's own)
    # This is different from index which may show observer's deleted observations
    observations = observations.where(deleted_at: nil)
    
    # Filter by observee_ids if provided
    if @observee_ids.any?
      observations = observations.joins(:observees)
                                 .where(observees: { teammate_id: @observee_ids })
                                 .distinct
    end
    
    # Filter by rateable_type and rateable_id if provided
    if @rateable_type.present? && @rateable_id.present?
      begin
        rateable = @rateable_type.constantize.find(@rateable_id)
        observations = observations.joins(:observation_ratings)
                                   .where(observation_ratings: { rateable_type: @rateable_type, rateable_id: @rateable_id })
                                   .distinct
      rescue ActiveRecord::RecordNotFound
        # Handle non-existent rateable_id gracefully
        observations = Observation.none
      end
    end
    
    # Filter by start_date if provided
    if @start_date.present?
      observations = observations.where('observed_at >= ?', @start_date)
    end
    
    # Filter by end_date if provided
    if @end_date.present?
      observations = observations.where('observed_at <= ?', @end_date)
    end

    # When observer_id is present (e.g. "View All Observations Given" from About Me), restrict to that observer and to published, non-journal
    if params[:observer_id].present?
      observations = observations.where(observer_id: params[:observer_id])
      observations = observations.merge(Observation.published).merge(Observation.not_journal)
    end

    # Sort by published date descending (most recent first)
    observations = observations.order(published_at: :desc)

    # Assign observations for the view
    @observations = observations.includes(:observer, { observed_teammates: :person }, :observation_ratings)
    
    # Build modal title based on filters
    if @rateable_type.present? && @rateable_id.present?
      begin
        rateable = @rateable_type.constantize.find(@rateable_id)
        @modal_title = "Observations for #{rateable.name || rateable.title}"
      rescue ActiveRecord::RecordNotFound
        @modal_title = "Observations"
      end
    elsif @observee_ids.any?
      teammate = CompanyTeammate.find(@observee_ids.first)
      @modal_title = "Observations for #{teammate.person.display_name}"
    else
      @modal_title = "Observations"
    end
    
    # Set return URL and text for overlay
    @return_url = params[:return_url] || organization_observations_path(organization)
    @return_text = params[:return_text] || 'Back to Observations'
    
    render layout: 'overlay'
  end

  def show
    # Show page is only for the observer
    begin
      authorize @observation, :show?
    rescue Pundit::NotAuthorizedError
      date_part = @observation.observed_at.strftime('%Y-%m-%d')
      redirect_to organization_kudo_path(@observation.company, date: date_part, id: @observation.id)
      return
    end

    # Create debug data if debug parameter is present
    if params[:debug] == 'true'
      debug_service = Debug::ObservationSlackDebugService.new(
        observation: @observation,
        organization: organization
      )
      @debug_data = debug_service.call
    end

    # Prepare privacy names for Details section (who can see this)
    prepare_privacy_selector_data

    # Load observation kudos awards for Spotlight section (when points have been awarded)
    @observation_kudos_awards = if PointsExchangeTransaction.exists?(observation: @observation)
      PointsExchangeTransaction.for_observation(@observation).includes(company_teammate: :person).map do |t|
        { person: t.company_teammate.person, points: t.points_to_spend_delta.to_f }
      end
    else
      []
    end

    # Load celebratory bank award for observable moment card (when observation has an observable moment)
    @observable_moment_bank_award = if @observation.observable_moment.present?
      CelebratoryAwardTransaction.find_by(observable_moment: @observation.observable_moment)
    end

    # Load data for the "great observation" section (only shown when published, no notifications, not journal, and observer)
    if @observation.published? && @observation.notifications.none? && @observation.privacy_level != 'observer_only' && current_person == @observation.observer
      # Load organizations with kudos channels (company + descendants)
      company = @observation.company
      organizations_with_channels = ([company] + company.descendants.to_a)
                                    .select { |org| org.kudos_channel_id.present? }
      
      # Build list of organizations with channel info
      @kudos_channel_organizations = organizations_with_channels.map do |org|
        channel = org.kudos_channel
        {
          organization: org,
          channel: channel,
          display_name: channel ? "#{org.display_name} - #{channel.display_name}" : org.display_name,
          already_sent: notification_already_sent_to_organization?(org.id)
        }
      end
      
      # Determine which teammates should be available for notification based on privacy level
      @available_teammates_for_notification = case @observation.privacy_level
      when 'public_to_company', 'public_to_world'
        # Public: show all observees and their managers
        build_public_observation_teammates_list
      when 'observed_only'
        # Only observees (excluding observer if they are also an observee)
        @observation.observed_teammates.reject { |t| t.person_id == @observation.observer_id }.map do |teammate|
          {
            teammate: teammate,
            role: "Observed",
            person: teammate.person
          }
        end
      when 'managers_only'
        # Only direct managers (level 0)
        teammates = []
        @observation.observed_teammates.each do |teammate|
          managers = ManagerialHierarchyQuery.new(
            person: teammate.person, 
            organization: company
          ).call
          
          # Only include level 0 (direct) managers
          managers.select { |m| m[:level] == 0 }.each do |manager_info|
            manager_teammate = company.teammates.find_by(person_id: manager_info[:person_id])
            next unless manager_teammate
            
            unless teammates.any? { |t| t[:teammate].id == manager_teammate.id }
              teammates << {
                teammate: manager_teammate,
                role: "Manager of #{teammate.person.casual_name}",
                person: manager_teammate.person
              }
            end
          end
        end
        teammates
      when 'observed_and_managers'
        # Observees (excluding observer) + direct managers only
        teammates = []
        # Add observees (excluding observer if they are also an observee)
        @observation.observed_teammates.reject { |t| t.person_id == @observation.observer_id }.each do |teammate|
          teammates << {
            teammate: teammate,
            role: "Observed",
            person: teammate.person
          }
        end
        # Add direct managers (level 0)
        @observation.observed_teammates.each do |teammate|
          managers = ManagerialHierarchyQuery.new(
            person: teammate.person, 
            organization: company
          ).call
          
          managers.select { |m| m[:level] == 0 }.each do |manager_info|
            manager_teammate = company.teammates.find_by(person_id: manager_info[:person_id])
            next unless manager_teammate
            
            unless teammates.any? { |t| t[:teammate].id == manager_teammate.id }
              teammates << {
                teammate: manager_teammate,
                role: "Manager of #{teammate.person.casual_name}",
                person: manager_teammate.person
              }
            end
          end
        end
        teammates
      else
        []
      end

      # Load data for points awarding row in nudge (observees excluding observer, observer ledger, already awarded?)
      observer_teammate = company.teammates.find_by(person: @observation.observer)
      @observer_ledger = observer_teammate&.kudos_ledger
      @observees_for_kudos = @observation.observees.includes(:company_teammate).reject { |o| o.company_teammate.person_id == @observation.observer_id }.map do |o|
        { person: o.company_teammate.person, role: "Observed" }
      end
      @kudos_not_yet_awarded = !PointsExchangeTransaction.exists?(observation: @observation)

      # Build per-rating reward options for the award form (positive ratings only)
      @positive_rating_reward_options = @observation.positive_ratings.includes(:rateable).map do |rating|
        rating_kind = rating.strongly_agree? ? :exceptional : :solid
        opts = helpers.peer_to_peer_point_options_for(company, rating_kind)
        {
          rating: rating,
          label: @observation.label_for_rating(rating),
          rating_kind: rating_kind,
          min: opts[:min],
          max: opts[:max],
          point_options: opts[:point_options]
        }
      end

      # Celebratory org-bank section in nudge: config, already awarded?, point options for dropdowns
      if @observation.observable_moment.present?
        moment_type = @observation.observable_moment.moment_type
        opts = helpers.celebratory_bank_point_options_for(company, moment_type)
        max_give = opts[:max_points_to_give].to_f
        max_spend = opts[:max_points_to_spend].to_f
        if max_give > 0 || max_spend > 0
          @celebratory_bank_config = { points_to_give: max_give, points_to_spend: max_spend }
          @celebratory_bank_already_awarded = CelebratoryAwardTransaction.exists?(observable_moment: @observation.observable_moment)
          @celebratory_bank_point_options = opts
        end
      end

      # Load page visit statistics from both show page and public permalink page
      @page_visit_stats = Observations::PageVisitStatsService.call(
        observation: @observation,
        organization: organization
      )
    end

  end

  def edit
    @observation = Observation.find(params[:id])
    authorize @observation, :edit?
    
    # Redirect to appropriate new_* action based on type
    case @observation.observation_type
    when 'kudos'
      redirect_to new_kudos_organization_observations_path(organization, draft_id: @observation.id, return_url: params[:return_url], return_text: params[:return_text])
    when 'feedback'
      redirect_to new_feedback_organization_observations_path(organization, draft_id: @observation.id, return_url: params[:return_url], return_text: params[:return_text])
    when 'quick_note'
      redirect_to new_quick_note_organization_observations_path(organization, draft_id: @observation.id, return_url: params[:return_url], return_text: params[:return_text])
    else
      redirect_to new_organization_observation_path(organization, draft_id: @observation.id, return_url: params[:return_url], return_text: params[:return_text])
    end
  end

  def new
    authorize Observation
    
    # Load observable moment if provided
    @observable_moment = ObservableMoment.find_by(id: params[:observable_moment_id]) if params[:observable_moment_id].present?
    
    # Load existing observation (draft or published) or create new draft
    if params[:draft_id].present? || params[:id].present?
      observation_id = params[:draft_id].presence || params[:id]
      @observation = Observation.find(observation_id)
      authorize @observation, :edit?
      
      # Don't reload - it wipes out fresh data. Just reload associations
      @observation.observation_ratings.reload if @observation.observation_ratings.loaded?
      
      Rails.logger.info "Loading existing observation #{@observation.id} (draft: #{@observation.draft?}), story: #{@observation.story.inspect}"
    else
      # Create new draft
      @observation = organization.observations.build(observer: current_person, observation_type: 'generic', created_as_type: 'generic')
      
      # Pre-fill from observable moment if present
      if @observable_moment
        load_observable_moment_context(@observable_moment)
      end
      
      # Set observees from params (may override moment suggestions)
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
      else
        # If no rateable is explicitly passed, automatically add root company aspirations only
        # (not department or team aspirations)
        root_company = organization.root_company || organization
        company_aspirations = root_company.aspirations.where(department_id: nil).ordered
        
        company_aspirations.each do |aspiration|
          rating = @observation.observation_ratings.build(
            rateable_type: 'Aspiration',
            rateable_id: aspiration.id
          )
          # Pre-load the rateable association so it's available for @observation.aspirations
          rating.rateable = aspiration
        end
      end
    end
    
    # Ensure observation_ratings are loaded for associations
    @observation.observation_ratings.load if @observation.observation_ratings.loaded?
    
    # Load available rateables
    @assignments = organization.assignments.unarchived.ordered
    @aspirations = organization.aspirations
    @abilities = organization.abilities.unarchived.order(:name)
    
    # Store return context - default to show page if editing existing observation, otherwise index or dashboard
    if @observation.persisted?
      @return_url = params[:return_url] || organization_observation_path(organization, @observation)
      @return_text = params[:return_text] || 'Back to Observation'
    else
      # If coming from observable moment, return to dashboard
      if @observable_moment
        @return_url = params[:return_url] || organization_get_shit_done_path(organization)
        @return_text = params[:return_text] || 'Back to Get Shit Done Dashboard'
      else
        @return_url = params[:return_url] || organization_observations_path(organization)
        @return_text = params[:return_text] || 'Back'
      end
    end
    
    prepare_privacy_selector_data
    
    render layout: 'overlay'
  end

  def prepare_privacy_selector_data
    # Get observee casual names - check both saved and unsaved observees
    saved_observees = @observation.observed_teammates.to_a
    unsaved_observees = @observation.observees.select { |o| o.new_record? && o.teammate_id.present? }
    all_observee_teammates = saved_observees + unsaved_observees.map { |o| o.teammate }.compact
    
    @observee_names = all_observee_teammates.map { |teammate| teammate.person.casual_name }
    
    # Get direct managers (level 0) and other managers (level > 0) for all observees
    # Use person_id to deduplicate across observees
    direct_manager_ids = Set.new
    other_manager_ids = Set.new
    manager_id_to_person = {}
    
    all_observee_teammates.each do |teammate|
      managers = ManagerialHierarchyQuery.new(person: teammate.person, organization: @observation.company).call
      managers.each do |manager_info|
        manager_id = manager_info[:person_id]
        manager_person = Person.find_by(id: manager_id)
        next unless manager_person
        
        manager_id_to_person[manager_id] = manager_person
        
        if manager_info[:level] == 0
          direct_manager_ids.add(manager_id)
        else
          other_manager_ids.add(manager_id)
        end
      end
    end
    
    # Remove direct managers from other managers list (in case someone is both)
    other_manager_ids = other_manager_ids - direct_manager_ids
    
    # Get casual names for direct managers
    @direct_manager_names = direct_manager_ids.map { |id| manager_id_to_person[id].casual_name }.sort
    
    # Get casual names for other managers (for popover)
    @other_manager_names = other_manager_ids.map { |id| manager_id_to_person[id].casual_name }.sort
    
    # Keep @manager_names for backward compatibility (all managers, display names)
    @manager_names = (direct_manager_ids + other_manager_ids).map { |id| manager_id_to_person[id].display_name }.sort
    
    # Check if only observee is the observer
    @only_observee_is_observer = all_observee_teammates.any? && 
                                  all_observee_teammates.all? { |teammate| teammate.person == @observation.observer }
    
    # Pass observation type
    @observation_type = @observation.observation_type
    
    # For generic observations, control privacy levels based on observees
    if @observation_type == 'generic'
      # Check both saved and unsaved observees
      # Load the association to ensure we check both saved and unsaved
      observees_collection = @observation.observees.to_a
      has_observees = observees_collection.any? { |o| o.teammate_id.present? && !o.marked_for_destruction? }
      
      if has_observees
        # All privacy levels enabled when there are observees
        @allowed_privacy_levels = Observation.privacy_levels.keys.map(&:to_sym)
        @disabled_levels = {}
      else
        # All privacy levels disabled when there are no observees
        @allowed_privacy_levels = []
        @disabled_levels = Observation.privacy_levels.keys.each_with_object({}) do |key, hash|
          hash[key.to_sym] = "Privacy levels require at least one observee. Please add observees first."
        end
      end
    end
  end

  def new_kudos
    authorize Observation, :create?
    setup_typed_observation('kudos', 'observed_and_managers')
    
    @allowed_privacy_levels = [:observed_only, :observed_and_managers, :public_to_company, :public_to_world]
    @disabled_levels = {
      observer_only: "Kudos should be shared... if you'd like to make this a journal entry, convert to generic observation",
      managers_only: "We should always share kudos with the people we are praising"
    }
    @show_gifs = true
    @show_convert_link = @observation.persisted?
    
    prepare_privacy_selector_data
    
    render 'new_kudos', layout: 'overlay'
  end

  def new_feedback
    authorize Observation, :create?
    setup_typed_observation('feedback', 'observed_only')
    
    # Pre-fill with MAAP template for new observations
    if @observation.new_record? && @observation.story.blank?
      @observation.story = maap_framework_template
    end
    
    @allowed_privacy_levels = [:observer_only, :observed_only, :managers_only, :observed_and_managers]
    @disabled_levels = {
      public_to_company: "Feedback should be delivered privately... if this isn't constructive and should be shared, convert to generic observation",
      public_to_world: "Feedback should be delivered privately... if this isn't constructive and should be shared, convert to generic observation"
    }
    @show_gifs = false
    @show_convert_link = @observation.persisted?
    
    prepare_privacy_selector_data
    
    render 'new_feedback', layout: 'overlay'
  end

  def new_quick_note
    authorize Observation, :create?
    
    # Use 'observed_and_managers' as default privacy when coming from check-ins (detected via return_url)
    default_privacy = params[:return_url].to_s.include?('check_ins') ? 'observed_and_managers' : 'observed_only'
    setup_typed_observation('quick_note', default_privacy)
    
    @allowed_privacy_levels = [:observer_only, :observed_only, :observed_and_managers]
    @disabled_levels = {
      managers_only: "Quick notes should be delivered privately... if this should be shared differently, convert to generic observation",
      public_to_company: "Quick notes should be delivered privately... if this should be shared differently, convert to generic observation",
      public_to_world: "Quick notes should be delivered privately... if this should be shared differently, convert to generic observation"
    }
    @show_gifs = false
    @show_convert_link = @observation.persisted?
    
    prepare_privacy_selector_data
    
    render 'new_quick_note', layout: 'overlay'
  end

  def create
    authorize Observation
    @observation = organization.observations.build(observer: current_person)
    @form = ObservationForm.new(@observation)
    
    # Set observable_moment_id if provided
    @form.observable_moment_id = params[:observation][:observable_moment_id] if params[:observation] && params[:observation][:observable_moment_id].present?
    
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
          
          # Enforce privacy level if public observation has negative ratings
          if Observations::PrivacyLevelEnforcementService.call(@observation)
            flash[:alert] = "Privacy level was changed from Public to 'For them and their managers' because this observation contains negative ratings."
          end
          
          # Redirect to return_url if provided, otherwise to show page
          redirect_url = params[:return_url].presence || organization_observation_path(organization, @observation)
          redirect_to redirect_url, notice: 'Observation was successfully created.'
        else
          # Re-populate the form with submitted values for re-rendering
          @assignments = organization.assignments.unarchived.ordered
          @aspirations = organization.aspirations
          @abilities = organization.abilities.unarchived.order(:name)
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
      
      @assignments = organization.assignments.unarchived.ordered
      @aspirations = organization.aspirations
      @abilities = organization.abilities.unarchived.order(:name)
      render :new, status: :unprocessable_entity
    end
  end


  def destroy
    # Destroy is only for the observer (within 24 hours) or admin
    begin
      authorize @observation, :destroy?
    rescue Pundit::NotAuthorizedError
      date_part = @observation.observed_at.strftime('%Y-%m-%d')
      redirect_to organization_kudo_path(@observation.company, date: date_part, id: @observation.id)
      return
    end

    @observation.soft_delete!
    redirect_to organization_observation_path(organization, @observation), 
                notice: 'Observation was successfully archived.'
  end

  def restore
    begin
      authorize @observation, :restore?
    rescue Pundit::NotAuthorizedError
      date_part = @observation.observed_at.strftime('%Y-%m-%d')
      redirect_to organization_kudo_path(@observation.company, date: date_part, id: @observation.id)
      return
    end
    
    @observation.restore!
    redirect_to organization_observation_path(organization, @observation), 
                notice: 'Observation was successfully restored.'
  end

  def journal
    authorize company, :view_observations?
    # Use ObservationVisibilityQuery for complex visibility logic
    visibility_query = ObservationVisibilityQuery.new(current_person, organization)
    @observations = visibility_query.visible_observations.journal.includes(:observer, :observed_teammates, :observation_ratings)
    @observations = @observations.recent
    
    # Calculate spotlight stats for the view
    @spotlight_stats = calculate_spotlight_stats(@observations)
    
    # Set default filter/sort/view/spotlight state
    @current_filters = {}
    @current_sort = 'recent'
    @current_view = 'list'
    @current_spotlight = nil
    
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
      @available_abilities = organization.abilities.unarchived
      @available_assignments = organization.assignments.unarchived
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
        @available_abilities = organization.abilities.unarchived.where(id: teammate_ids.map(&:to_i))
        @available_assignments = organization.assignments.unarchived.where(id: teammate_ids.map(&:to_i))
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
      
      # Enforce privacy level if public observation has negative ratings
      if Observations::PrivacyLevelEnforcementService.call(@observation)
        flash[:alert] = "Privacy level was changed from Public to 'For them and their managers' because this observation contains negative ratings."
      end
      
      # Send notifications if requested
      if params[:observation][:send_notifications] == '1'
        notify_teammate_ids = params[:observation][:notify_teammate_ids] || []
        Observations::PostNotificationJob.perform_and_get_result(@observation.id, notify_teammate_ids)
      end
      
      # Clear wizard data
      session[:observation_wizard_data] = nil
      
      # Redirect to return_url if provided, otherwise to show page
      redirect_url = params[:return_url].presence || organization_observation_path(organization, @observation)
      redirect_to redirect_url, notice: 'Observation was successfully created.'
    else
      # Re-populate form and show errors
      populate_form_from_wizard_data(@form, wizard_data)
      teammate_ids = wizard_data['teammate_ids'] || []
      @observees_for_notifications = organization.teammates.where(id: teammate_ids.map(&:to_i)).includes(:person)
      
      render :review, status: :unprocessable_entity
    end
  end

  def share_publicly
    authorize @observation, :post_to_slack?
    # Disallow if draft
    if @observation.draft?
      redirect_to organization_observation_path(organization, @observation), 
                  alert: 'Draft observations cannot be shared.'
      return
    end
    # Only allow if observation is public
    unless @observation.can_post_to_slack_channel?
      redirect_to organization_observation_path(organization, @observation), 
                  alert: 'Only public observations can be shared publicly.'
      return
    end
    
    # Load organizations with kudos channels (company + descendants)
    company = @observation.company
    organizations_with_channels = ([company] + company.descendants.to_a)
                                  .select { |org| org.kudos_channel_id.present? }
    
    # Build list of organizations with channel info
    @kudos_channel_organizations = organizations_with_channels.map do |org|
      channel = org.kudos_channel
      {
        organization: org,
        channel: channel,
        display_name: channel ? "#{org.display_name} - #{channel.display_name}" : org.display_name,
        already_sent: notification_already_sent_to_organization?(org.id)
      }
    end
    
    # Set return URL for overlay
    @return_url = organization_observation_path(organization, @observation)
    @return_text = 'Back to Observation'
    
    render layout: 'overlay'
  end

  def share_privately
    authorize @observation, :post_to_slack?
    # Disallow if draft
    if @observation.draft?
      redirect_to organization_observation_path(organization, @observation), 
                  alert: 'Draft observations cannot be shared.'
      return
    end
    # Disallow if journal (observer_only)
    if @observation.privacy_level == 'observer_only'
      redirect_to organization_observation_path(organization, @observation), 
                  alert: 'Journal entries cannot be shared privately.'
      return
    end
    
    # Determine which teammates should be available for notification
    @available_teammates = if @observation.privacy_level == 'public_to_company' || 
                               @observation.privacy_level == 'public_to_world'
      # Public: show all observees and their managers
      build_public_observation_teammates_list
    else
      # Not public: show only those who should have access
      build_private_observation_teammates_list
    end
    
    # Exclude the observer from the list since they're always included in the DM
    observer_teammate = @observation.company.teammates.find_by(person: @observation.observer)
    if observer_teammate
      @available_teammates = @available_teammates.reject { |t| t[:teammate].id == observer_teammate.id }
    end
    
    # Mark teammates with disabled status and reason
    @available_teammates.each do |teammate_info|
      teammate = teammate_info[:teammate]
      
      # Check if already notified
      # Check both individual DMs and group DMs that include this teammate
      already_notified = if teammate.slack_user_id.present?
        # Check for individual DM (channel is the teammate's slack_user_id and not a group DM)
        individual_dm = @observation.notifications
                                   .where(notification_type: 'observation_dm')
                                   .where("metadata->>'channel' = ?", teammate.slack_user_id.to_s)
                                   .where("(metadata->>'is_group_dm' != 'true' OR metadata->>'is_group_dm' IS NULL)")
                                   .successful
                                   .exists?
        
        # Check for group DM that includes this teammate
        # teammate_ids is stored as an array in JSON, check if it contains this teammate's ID
        # Use JSONB containment operator: @> checks if left JSON contains right JSON
        group_dm = @observation.notifications
                              .where(notification_type: 'observation_dm')
                              .where("metadata->>'is_group_dm' = 'true'")
                              .where("metadata->'teammate_ids' @> ?", [teammate.id].to_json)
                              .successful
                              .exists?
        
        individual_dm || group_dm
      else
        false
      end
      
      teammate_info[:disabled] = !teammate.has_slack_identity? || already_notified
      teammate_info[:disabled_reason] = if !teammate.has_slack_identity?
        'Slack not configured for them'
      elsif already_notified
        'Already notified in a prior notification'
      else
        nil
      end
    end
    
    # Set return URL for overlay
    @return_url = organization_observation_path(organization, @observation)
    @return_text = 'Back to Observation'
    
    render layout: 'overlay'
  end

  # Slack posting from show page
  def post_to_slack
    Rails.logger.info "🔍🔍🔍🔍🔍 ObservationController::post_to_slack: About to authorize Observation"
    authorize @observation, :post_to_slack?
    
    # Disallow if draft
    if @observation.draft?
      redirect_to organization_observation_path(organization, @observation), 
                  alert: 'Draft observations cannot be shared.'
      return
    end
    
    notify_teammate_ids = params[:notify_teammate_ids] || []
    kudos_channel_organization_id = params[:kudos_channel_organization_id]
    
    Rails.logger.info "🔍🔍🔍🔍🔍 ObservationController::post_to_slack: perform: @observation.id: #{@observation.id}, notify_teammate_ids: #{notify_teammate_ids}, kudos_channel_organization_id: #{kudos_channel_organization_id}"
    Observations::PostNotificationJob.perform_and_get_result(
      @observation.id, 
      notify_teammate_ids,
      kudos_channel_organization_id
    )
    
    redirect_to organization_observation_path(organization, @observation), 
                notice: 'Notifications sent successfully'
  end

  def award_kudos
    authorize @observation, :award_kudos?

    raw = params.permit(award_by_rating: {}).fetch(:award_by_rating, {}) || {}
    rating_rewards = []
    raw.each do |rating_id_s, attrs|
      next if attrs.blank?
      reward = attrs['reward'].to_s
      points_s = attrs['points'].to_s.strip
      next if reward.blank? || reward == '0' || points_s.blank?
      points_value = points_s.to_f
      next if points_value <= 0
      rating = @observation.observation_ratings.positive.find_by(id: rating_id_s)
      next unless rating
      rating_rewards << { observation_rating_id: rating.id, points: (points_value * 2).ceil / 2.0 }
    end

    if rating_rewards.empty?
      redirect_to organization_observation_path(organization, @observation), alert: 'Please select at least one rating and enter points.'
      return
    end

    total = rating_rewards.sum { |r| r[:points] }
    if total <= 0
      redirect_to organization_observation_path(organization, @observation), alert: 'Please select at least one rating and enter points.'
      return
    end

    result = Kudos::AwardObservationPointsFromObserverService.call(observation: @observation, rating_rewards: rating_rewards)

    if result.ok?
      redirect_to organization_observation_path(organization, @observation), notice: 'Points awarded successfully.'
    else
      redirect_to organization_observation_path(organization, @observation), alert: result.error
    end
  end

  def award_celebratory_kudos
    authorize @observation, :award_kudos?

    unless @observation.observable_moment.present?
      redirect_to organization_observation_path(organization, @observation), alert: 'This observation has no observable moment.'
      return
    end

    if CelebratoryAwardTransaction.exists?(observable_moment: @observation.observable_moment)
      redirect_to organization_observation_path(organization, @observation), alert: 'Celebratory points have already been awarded for this observable moment.'
      return
    end

    opts = helpers.celebratory_bank_point_options_for(organization, @observation.observable_moment.moment_type)
    max_give = opts[:max_points_to_give].to_f
    max_spend = opts[:max_points_to_spend].to_f
    if max_give <= 0 && max_spend <= 0
      redirect_to organization_observation_path(organization, @observation), alert: 'No celebratory point configuration for this moment type.'
      return
    end

    points_to_give = params[:points_to_give].present? ? params[:points_to_give].to_s.strip : nil
    points_to_spend = params[:points_to_spend].present? ? params[:points_to_spend].to_s.strip : nil

    result = Kudos::AwardCelebratoryPointsService.call(
      observable_moment: @observation.observable_moment,
      observation: @observation,
      points_to_give: points_to_give,
      points_to_spend: points_to_spend
    )

    if result.ok?
      redirect_to organization_observation_path(organization, @observation), notice: 'Celebratory points awarded successfully.'
    else
      redirect_to organization_observation_path(organization, @observation), alert: result.error
    end
  end

  # Public action methods (must be before private keyword)
  # Update draft observation
  def update_draft
    # Handle new observations (id = 'new' or coming from collection route)
    if params[:id].nil? || params[:id] == 'new' || params[:id].to_s == 'new'
      # Extract observation_type from params
      permitted_params = draft_params
      observation_type = permitted_params[:observation_type] || 'generic'
      
      # Create new observation - build from params and save
      @observation = organization.observations.build(observer: current_person)
      @observation.observation_type = observation_type
      # Set created_as_type only if it doesn't exist (preserve existing value if present)
      @observation.created_as_type ||= observation_type
      
      # If observable_moment_id is in URL params but not in form params, add it
      if params[:observable_moment_id].present? && permitted_params[:observable_moment_id].blank?
        permitted_params[:observable_moment_id] = params[:observable_moment_id]
      end
      
      # Also set the association directly on the observation if observable_moment_id is present
      if permitted_params[:observable_moment_id].present?
        observable_moment = ObservableMoment.find_by(id: permitted_params[:observable_moment_id])
        @observation.observable_moment = observable_moment if observable_moment
      end
      
      # Set observees from params if provided
      observee_ids = params[:observee_ids] || []
      observee_ids = [observee_ids] unless observee_ids.is_a?(Array)
      observee_ids.each do |teammate_id|
        next if teammate_id.blank?
        @observation.observees.build(teammate_id: teammate_id)
      end
      
      # Use Reform to handle nested attributes properly and avoid duplicates
      @form = ObservationForm.new(@observation)
      
      # Set observable_moment_id if provided in params, or use existing from observation (check both persisted and in-memory)
      # Also check URL params in case it wasn't in form submission
      observable_moment_id = permitted_params[:observable_moment_id] || 
                             params[:observable_moment_id] ||
                             @observation.observable_moment_id || 
                             (@observation.observable_moment&.id)
      @form.observable_moment_id = observable_moment_id if observable_moment_id.present?
      
      if @form.validate(permitted_params)
        @form.save
        @observation = @form.model
        @observation.observed_at ||= Time.current
        @observation.save! if @observation.changed? || @observation.new_record?
        authorize @observation, :update?
        
        # Enforce privacy level if public observation has negative ratings
        if Observations::PrivacyLevelEnforcementService.call(@observation)
          flash[:alert] = "Privacy level was changed from Public to 'For them and their managers' because this observation contains negative ratings."
        end
      else
        flash[:alert] = "Failed to save: #{@form.errors.full_messages.join(', ')}"
        @return_url = determine_return_url
        @return_text = params[:return_text] || 'Back'
        @assignments = organization.assignments.unarchived.ordered
        @aspirations = organization.aspirations
        @abilities = organization.abilities.unarchived.order(:name)
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
    
    # Set observable_moment_id if provided in params, or use existing from observation (check both persisted and in-memory)
    observable_moment_id = permitted_params[:observable_moment_id] || 
                           @observation.observable_moment_id || 
                           (@observation.observable_moment&.id)
    @form.observable_moment_id = observable_moment_id if observable_moment_id.present?
    
    ready_to_save = @form.validate(permitted_params)
    saved = ready_to_save ? @form.save : false
    
    # Ensure @observation is set to the form's model after save
    @observation = @form.model if saved
    
    if saved
      # Enforce privacy level if public observation has negative ratings
      if Observations::PrivacyLevelEnforcementService.call(@observation)
        flash[:alert] = "Privacy level was changed from Public to 'For them and their managers' because this observation contains negative ratings."
      end
      
      # Check if we should save and navigate to an add-* picker
      # For save_and_add_* actions, use typed_observation_path_for to get the correct return_url
      typed_return_url = typed_observation_path_for(@observation, return_url: params[:return_url], return_text: params[:return_text])
      if params[:save_and_add_assignments].present?
        redirect_params = {}
        redirect_params[:return_url] = typed_return_url
        redirect_params[:return_text] = params[:return_text] if params[:return_text].present?
        redirect_to add_assignments_organization_observation_path(organization, @observation, redirect_params)
      elsif params[:save_and_add_aspirations].present?
        redirect_params = {}
        redirect_params[:return_url] = typed_return_url
        redirect_params[:return_text] = params[:return_text] if params[:return_text].present?
        redirect_to add_aspirations_organization_observation_path(organization, @observation, redirect_params)
      elsif params[:save_and_add_abilities].present?
        redirect_params = {}
        redirect_params[:return_url] = typed_return_url
        redirect_params[:return_text] = params[:return_text] if params[:return_text].present?
        redirect_to add_abilities_organization_observation_path(organization, @observation, redirect_params)
      elsif params[:save_and_manage_observees].present?
        redirect_params = {}
        redirect_params[:return_url] = typed_return_url
        redirect_params[:return_text] = params[:return_text] if params[:return_text].present?
        redirect_to manage_observees_organization_observation_path(organization, @observation, redirect_params)
      elsif params[:save_and_convert_to_generic].present?
        @observation.update!(observation_type: 'generic')
        redirect_params = { draft_id: @observation.id }
        # Use the provided return_url or default to observations index
        redirect_params[:return_url] = params[:return_url] if params[:return_url].present?
        redirect_params[:return_text] = params[:return_text] if params[:return_text].present?
        redirect_to new_organization_observation_path(organization, redirect_params), notice: 'Converted to generic observation. All features are now available.'
      elsif params[:save_draft_and_return].present?
        # Convert published observation to draft if it was published
        if @observation.published_at.present?
          @observation.update_column(:published_at, nil)
        end
        # Save draft and return to the specified return_url, or observation show page, or observations index
        redirect_url = params[:return_url].presence || (@observation.present? ? organization_observation_path(organization, @observation) : organization_observations_path(organization))
        redirect_to redirect_url, notice: 'Draft saved successfully.'
      else
        # If return_url is provided, redirect there; otherwise go to observation show page
        redirect_url = params[:return_url].presence || organization_observation_path(organization, @observation)
        redirect_to redirect_url, notice: 'Observation was successfully saved.'
      end
    else
      Rails.logger.error "Failed to update: #{@observation.errors.full_messages.join(', ')}"
      Rails.logger.error "Attempted params: #{permitted_params.inspect}"
      flash[:alert] = "Failed to update: #{@observation.errors.full_messages.join(', ')}"
      @return_url = determine_return_url
      @return_text = params[:return_text]
      @assignments = organization.assignments.unarchived.ordered
      @aspirations = organization.aspirations
      @abilities = organization.abilities.unarchived.order(:name)
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
        
        # Enforce privacy level if public observation has negative ratings
        if Observations::PrivacyLevelEnforcementService.call(@observation)
          flash[:alert] = "Privacy level was changed from Public to 'For them and their managers' because this observation contains negative ratings."
        end
      end
    else
      # Existing observation - update with any form data if story has content
      @observation = Observation.find(params[:id])
      authorize @observation, :update?
      
      story = params[:observation] && params[:observation][:story] ? params[:observation][:story] : @observation.story
      
      if story.present? && story.strip.present? && params[:observation].present?
        # Update observation with form data
        @observation.update(draft_params)
        
        # Enforce privacy level if public observation has negative ratings
        if Observations::PrivacyLevelEnforcementService.call(@observation)
          flash[:alert] = "Privacy level was changed from Public to 'For them and their managers' because this observation contains negative ratings."
        end
      end
    end
    
    # Always redirect to return_url (even if no draft was saved)
    redirect_url = params[:return_url] || organization_observations_path(organization)
    redirect_to redirect_url
  end

  def notification_already_sent_to_organization?(organization_id)
    @observation.notifications
                .where(notification_type: 'observation_channel')
                .where("metadata->>'is_main_message' = 'true'")
                .where("metadata->>'organization_id' = ?", organization_id.to_s)
                .successful
                .exists?
  end

  def build_public_observation_teammates_list
    teammates = []
    observer_id = @observation.observer_id

    # Add observees (excluding observer if they are also an observee)
    @observation.observed_teammates.each do |teammate|
      next if teammate.person_id == observer_id

      teammates << {
        teammate: teammate,
        role: "Observed",
        person: teammate.person
      }
    end

    # Add direct managers only (level 0), not managers of managers
    @observation.observed_teammates.each do |teammate|
      managers = ManagerialHierarchyQuery.new(
        person: teammate.person,
        organization: @observation.company
      ).call

      managers.select { |m| m[:level] == 0 }.each do |manager_info|
        manager_teammate = @observation.company.teammates.find_by(person_id: manager_info[:person_id])
        next unless manager_teammate

        unless teammates.any? { |t| t[:teammate].id == manager_teammate.id }
          teammates << {
            teammate: manager_teammate,
            role: "Manager of #{teammate.person.casual_name}",
            person: manager_teammate.person
          }
        end
      end
    end

    teammates
  end

  def build_private_observation_teammates_list
    teammates = []
    company = @observation.company
    
    # Always include the observer if they have Slack configured
    observer_teammate = company.teammates.find_by(person: @observation.observer)
    if observer_teammate&.has_slack_identity?
      teammates << {
        teammate: observer_teammate,
        role: "Observer",
        person: observer_teammate.person
      }
    end
    
    case @observation.privacy_level
    when 'observed_only'
      # Observer + observees only
      @observation.observed_teammates.each do |teammate|
        teammates << {
          teammate: teammate,
          role: "Observed",
          person: teammate.person
        }
      end
    when 'managers_only'
      # Observer + managers only
      @observation.observed_teammates.each do |teammate|
        managers = ManagerialHierarchyQuery.new(
          person: teammate.person, 
          organization: company
        ).call
        
        managers.each do |manager_info|
          manager_teammate = company.teammates.find_by(person_id: manager_info[:person_id])
          next unless manager_teammate
          
          unless teammates.any? { |t| t[:teammate].id == manager_teammate.id }
            teammates << {
              teammate: manager_teammate,
              role: "Manager of #{teammate.person.casual_name}",
              person: manager_teammate.person
            }
          end
        end
      end
    when 'observed_and_managers'
      # Observer (added above) + observees (excl. observer) + direct managers from public list
      public_teammates = build_public_observation_teammates_list
      # Merge with existing teammates (avoid duplicates)
      public_teammates.each do |public_teammate|
        unless teammates.any? { |t| t[:teammate].id == public_teammate[:teammate].id }
          teammates << public_teammate
        end
      end
    end
    
    teammates
  end

  def convert_to_generic
    @observation = Observation.find(params[:id])
    authorize @observation, :update?
    
    @observation.update!(observation_type: 'generic')
    
    redirect_to new_organization_observation_path(
      organization,
      draft_id: @observation.id,
      return_url: params[:return_url],
      return_text: params[:return_text]
    ), notice: 'Converted to generic observation. All features are now available.'
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
      # Enforce privacy level if public observation has negative ratings
      if Observations::PrivacyLevelEnforcementService.call(@observation)
        flash[:alert] = "Privacy level was changed from Public to 'For them and their managers' because this observation contains negative ratings."
      end
      
      redirect_to add_assignments_organization_observation_path(
        organization, 
        @observation,
        return_url: params[:return_url] || typed_observation_path_for(@observation),
        return_text: params[:return_text] || 'Draft'
      )
    else
      # If save fails, redirect back with errors
      flash[:alert] = "Failed to save: #{@observation.errors.full_messages.join(', ')}"
      redirect_to typed_observation_path_for(@observation, return_url: params[:return_url], return_text: params[:return_text])
    end
  end

  # Show page for adding assignments to draft
  def add_assignments
    @observation = Observation.find(params[:id])
    authorize @observation, :update?
    
    # Load available assignments
    @assignments = organization.assignments.unarchived.ordered
    
    # Store return context
    @return_url = params[:return_url] || typed_observation_path_for(@observation)
    @return_text = params[:return_text] || 'Back'
    
    render layout: 'overlay'
  end

  # Show page for adding aspirations to draft
  def add_aspirations
    @observation = Observation.find(params[:id])
    authorize @observation, :update?
    
    @aspirations = organization.aspirations
    
    @return_url = params[:return_url] || typed_observation_path_for(@observation)
    @return_text = params[:return_text] || 'Back'
    
    render layout: 'overlay'
  end

  # Show page for adding abilities to draft
  def add_abilities
    @observation = Observation.find(params[:id])
    authorize @observation, :update?
    
    @abilities = organization.abilities.unarchived.order(:name)
    
    @return_url = params[:return_url] || typed_observation_path_for(@observation)
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
      # Preserve existing observable_moment_id if not in params
      params_to_update = draft_params.dup
      if @observation.observable_moment_id.present? && params_to_update[:observable_moment_id].blank?
        params_to_update[:observable_moment_id] = @observation.observable_moment_id
      end
      @observation.update(params_to_update)
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
    
    # Enforce privacy level if public observation has negative ratings
    if Observations::PrivacyLevelEnforcementService.call(@observation)
      flash[:alert] = "Privacy level was changed from Public to 'For them and their managers' because this observation contains negative ratings."
    end
    
    # Preserve return_url and return_text when redirecting back
    redirect_url = params[:return_url] || typed_observation_path_for(@observation)
    if params[:return_url].present? || params[:return_text].present?
      redirect_url = typed_observation_path_for(@observation, return_url: params[:return_url], return_text: params[:return_text])
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
      
      # Reload to ensure we have fresh data before calculating changes
      @observation.reload
      
      # Get current observee teammate IDs (distinct to handle any duplicates)
      current_observee_ids = @observation.observees.pluck(:teammate_id).uniq
      
      # Determine which observees to add and which to remove
      observees_to_add = teammate_ids - current_observee_ids
      observees_to_remove = current_observee_ids - teammate_ids
      
      # Remove observees that are no longer selected
      removed_count = 0
      observees_to_remove.each do |teammate_id|
        count = @observation.observees.where(teammate_id: teammate_id).count
        @observation.observees.where(teammate_id: teammate_id).destroy_all
        removed_count += count
      end
      
      # Add new observees
      added_count = 0
      observees_to_add.each do |teammate_id|
        # Check if it already exists (might have been added by another process)
        unless @observation.observees.exists?(teammate_id: teammate_id)
          Observations::AddObserveeService.new(observation: @observation, teammate_id: teammate_id).call
          added_count += 1
        end
      end
      
      # Build success message
      if added_count > 0 && removed_count > 0
        notice = "Added #{added_count} observee(s) and removed #{removed_count} observee(s)"
      elsif added_count > 0
        notice = "Added #{added_count} observee(s)"
      elsif removed_count > 0
        notice = "Removed #{removed_count} observee(s)"
      else
        notice = "No changes made"
      end
      
      # Use typed path if return_url is not provided, otherwise use return_url with optional return_text
      if params[:return_url].present?
        redirect_url = typed_observation_path_for(@observation, return_url: params[:return_url], return_text: params[:return_text])
      else
        redirect_url = typed_observation_path_for(@observation, return_text: params[:return_text])
      end
      redirect_to redirect_url, notice: notice
    else
      # GET - render picker
      @teammates = organization.teammates
        .joins(:person)
        .includes(:person)
        .order(Arel.sql('people.last_name, COALESCE(people.preferred_name, people.first_name)'))
      @return_url = params[:return_url] || typed_observation_path_for(@observation)
      @return_text = params[:return_text] || 'Back'
      render layout: 'overlay'
    end
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
      
      # Set observable_moment_id if provided
      @form.observable_moment_id = params[:observation][:observable_moment_id] if params[:observation] && params[:observation][:observable_moment_id].present?
      
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
        @assignments = organization.assignments.unarchived.ordered
        @aspirations = organization.aspirations
        @abilities = organization.abilities.unarchived.order(:name)
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
        
        # Set observable_moment_id if provided
        @form.observable_moment_id = params[:observation][:observable_moment_id] if params[:observation][:observable_moment_id].present?
        
        if @form.validate(draft_params)
          @form.save
        else
          Rails.logger.error "Publish validation failed: #{@form.errors.full_messages}"
          @return_url = params[:return_url] || organization_observations_path(organization)
          @return_text = params[:return_text] || 'Back'
          @assignments = organization.assignments.unarchived.ordered
          @aspirations = organization.aspirations
          @abilities = organization.abilities.unarchived.order(:name)
          flash[:alert] = "Cannot publish: #{@form.errors.full_messages.join(', ')}"
          render :new, layout: 'overlay', status: :unprocessable_entity
          return
        end
      end
    end
    
    # Publish will validate story is present (required for published observations)
    begin
      # Use service to publish, which handles na rating removal and privacy enforcement
      privacy_changed = Observations::PublishService.call(@observation)
      
      if privacy_changed
        flash[:alert] = "Privacy level was changed from Public to 'For them and their managers' because this observation contains negative ratings."
      end
      
      # If return_url is provided and is not edit/index, use it (from form/new page)
      # Otherwise, redirect to show page (publish from show page, edit page, or index)
      if params[:return_url].present? && !should_redirect_to_show_page?(params[:return_url])
        redirect_url = params[:return_url]
        
        # Add show_observations_for param if provided (only if not already in return_url)
        if params[:show_observations_for].present?
          # Only add if not already in the return_url
          unless redirect_url.include?('show_observations_for=')
            redirect_url += redirect_url.include?('?') ? '&' : '?'
            redirect_url += "show_observations_for=#{params[:show_observations_for]}"
          end
        end
        
        redirect_to redirect_url, notice: 'Observation was successfully published.'
      else
        redirect_url = organization_observation_path(organization, @observation)
        redirect_to redirect_url, notice: 'Observation was successfully published.'
      end
    rescue ActiveRecord::RecordInvalid => e
      # Validation failed - handle based on context
      if params[:return_url].present?
        # From form/new page - render form with errors
        @return_url = params[:return_url] || organization_observations_path(organization)
        @return_text = params[:return_text] || 'Back'
        @assignments = organization.assignments.unarchived.ordered
        @aspirations = organization.aspirations
        @abilities = organization.abilities.unarchived.order(:name)
        flash[:alert] = "Cannot publish: #{@observation.errors.full_messages.join(', ')}"
        render :new, layout: 'overlay', status: :unprocessable_entity
      else
        # From show page - redirect back with error
        redirect_to organization_observation_path(organization, @observation),
                    alert: "Cannot publish: #{@observation.errors.full_messages.join(', ')}"
      end
    end
  end

  # Override user_not_authorized to redirect to kudos page for observation show actions
  def user_not_authorized
    # For observation show actions, redirect to kudos page instead of root
    if action_name == 'show' && @observation.present?
      date_part = @observation.observed_at.strftime('%Y-%m-%d')
      redirect_to organization_kudo_path(@observation.company, date: date_part, id: @observation.id)
      return
    end
    
    # For all other cases, use the default behavior
    super
  end

  private

  def base_filtered(query)
    # Get filtered observations without sorting (to get accurate count)
    observations = query.base_scope
    observations = query.filter_by_privacy_levels(observations)
    observations = query.filter_by_timeframe(observations)
    observations = query.filter_by_draft_status(observations)
    observations = query.filter_by_observer(observations)
    observations = query.filter_by_involving_teammate(observations)
    observations
  end

  def setup_typed_observation(type, default_privacy)
    # Similar to existing new action but type-specific
    # Load existing observation (draft or published) or create new draft
    if params[:draft_id].present? || params[:id].present?
      observation_id = params[:draft_id].presence || params[:id]
      @observation = Observation.find(observation_id)
      authorize @observation, :edit?
      
      # Don't reload - it wipes out fresh data. Just reload associations
      @observation.observation_ratings.reload if @observation.observation_ratings.loaded?
    else
      # Create new draft
      @observation = organization.observations.build(observer: current_person, observation_type: type, created_as_type: type)
      
      # Set observees from params
      observee_ids = params[:observee_ids] || []
      observee_ids.each do |teammate_id|
        next if teammate_id.blank?
        @observation.observees.build(teammate_id: teammate_id)
      end
      
      @observation.privacy_level = params[:privacy_level] || default_privacy
      @observation.observed_at ||= Time.current
      
      # Add initial rateable if provided (build in memory, not saved)
      if params[:rateable_type].present? && params[:rateable_id].present?
        rateable = params[:rateable_type].constantize.find(params[:rateable_id])
        rating = @observation.observation_ratings.build(
          rateable_type: params[:rateable_type],
          rateable_id: params[:rateable_id]
        )
        rating.rateable = rateable
      else
        # If no rateable is explicitly passed, automatically add root company aspirations only
        root_company = organization.root_company || organization
        company_aspirations = root_company.aspirations.where(department_id: nil).ordered

        company_aspirations.each do |aspiration|
          rating = @observation.observation_ratings.build(
            rateable_type: 'Aspiration',
            rateable_id: aspiration.id
          )
          rating.rateable = aspiration
        end
      end
    end
    
    # Ensure observation_ratings are loaded for associations
    @observation.observation_ratings.load if @observation.observation_ratings.loaded?
    
    # Load available rateables
    @assignments = organization.assignments.unarchived.ordered
    @aspirations = organization.aspirations
    @abilities = organization.abilities.unarchived.order(:name)
    
    # Store return context
    @return_url = params[:return_url] || organization_observations_path(organization)
    @return_text = params[:return_text] || 'Back'
  end

  def maap_framework_template
    <<~TEMPLATE
      1. Your intent with this feedback / story
      --Are you expecting a response, a change, or do you just want those in the story to know your perspective--

      2. Situation / Context
      --What was happening--

      3. Observation 
      --Just the facts about what happened / observable behaviors / no editorializing or judgements here, just the facts--

      4. Feelings / Impact
      --Use the feeling dropdowns below--

      5. Unmet needs
      --Your unmet needs, or if this is a celebratory story, needs that were exceeded--

      6. Request
      --This goes back to the intent... if you have a specific request for the future, put them here... this is where a conversation will have to happen to see if those in your story agree to the requests--
    TEMPLATE
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
        total_public: observations.where(privacy_level: [:public_to_company, :public_to_world]).count,
        this_week: observations.where(privacy_level: [:public_to_company, :public_to_world], observed_at: 1.week.ago..).count,
        this_month: observations.where(privacy_level: [:public_to_company, :public_to_world], observed_at: 1.month.ago..).count,
        with_ratings: observations_relation.where(privacy_level: [:public_to_company, :public_to_world]).joins(:observation_ratings).distinct.count,
        positive_ratings: observations_relation.where(privacy_level: [:public_to_company, :public_to_world])
                                                .joins(:observation_ratings)
                                                .where(observation_ratings: { rating: [:strongly_agree, :agree] })
                                                .distinct.count
      }
    when 'this_week'
      {
        total_this_week: observations.where(observed_at: 1.week.ago..).count,
        journal_entries: observations.where(privacy_level: :observer_only, observed_at: 1.week.ago..).count,
        public_observations: observations.where(privacy_level: [:public_to_company, :public_to_world], observed_at: 1.week.ago..).count,
        with_ratings: observations_relation.where(observed_at: 1.week.ago..).joins(:observation_ratings).distinct.count
      }
    when 'feedback_health'
      calculate_feedback_health_stats
    when 'most_observed'
      calculate_most_observed_stats(observations_relation)
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

  def calculate_feedback_health_stats
    # Query ALL observations for the organization (ignoring visibility filters for company-wide health)
    all_observations = Observation.for_company(organization).where(deleted_at: nil)
    
    # Timeframes
    three_weeks_ago = 3.weeks.ago
    three_months_ago = 3.months.ago
    
    # Privacy levels
    privacy_levels = ['observer_only', 'observed_only', 'managers_only', 'observed_and_managers', 'public_to_company', 'public_to_world']
    
    # Build matrix data
    matrix = {}
    
    privacy_levels.each do |privacy_level|
      matrix[privacy_level] = {}
      
      # For each privacy level, calculate counts for each timeframe
      ['three_weeks', 'three_months', 'all_time'].each do |timeframe|
        scope = all_observations.where(privacy_level: privacy_level)
        
        case timeframe
        when 'three_weeks'
          scope = scope.where('observed_at >= ?', three_weeks_ago)
        when 'three_months'
          scope = scope.where('observed_at >= ?', three_months_ago)
        when 'all_time'
          # No time filter
        end
        
        # Calculate notified/published/created
        created_count = scope.count
        published_count = scope.where.not(published_at: nil).count
        notified_count = scope.joins(:notifications)
                              .where(notifications: { status: 'sent_successfully' })
                              .distinct
                              .count
        
        matrix[privacy_level][timeframe] = {
          created: created_count,
          published: published_count,
          notified: notified_count
        }
      end
    end
    
    # Calculate teammate participation stats (only published observations)
    published_observations = all_observations.where.not(published_at: nil)
    
    # Given feedback stats
    given_stats = calculate_given_feedback_stats(published_observations, three_weeks_ago, three_months_ago)
    
    # Received feedback stats
    received_stats = calculate_received_feedback_stats(published_observations, three_weeks_ago, three_months_ago)
    
    {
      matrix: matrix,
      given_stats: given_stats,
      received_stats: received_stats
    }
  end

  def calculate_given_feedback_stats(published_observations, three_weeks_ago, three_months_ago)
    stats = {}
    
    ['three_weeks', 'three_months', 'all_time'].each do |timeframe|
      scope = published_observations
      
      case timeframe
      when 'three_weeks'
        scope = scope.where('observed_at >= ?', three_weeks_ago)
      when 'three_months'
        scope = scope.where('observed_at >= ?', three_months_ago)
      when 'all_time'
        # No time filter
      end
      
      # Count unique observers
      all_observers = scope.distinct.pluck(:observer_id)
      
      # Count observers who gave positive feedback (only positive ratings, no negative)
      positive_observers = scope.joins(:observation_ratings)
                                .where.not(observation_ratings: { rating: [:disagree, :strongly_disagree] })
                                .group('observations.id')
                                .having('COUNT(CASE WHEN observation_ratings.rating IN (?, ?) THEN 1 END) > 0', 'strongly_agree', 'agree')
                                .having('COUNT(CASE WHEN observation_ratings.rating IN (?, ?) THEN 1 END) = 0', 'disagree', 'strongly_disagree')
                                .distinct
                                .pluck(:observer_id)
      
      # Count observers who gave constructive feedback (has any negative ratings)
      constructive_observers = scope.joins(:observation_ratings)
                                   .where(observation_ratings: { rating: [:disagree, :strongly_disagree] })
                                   .distinct
                                   .pluck(:observer_id)
      
      stats[timeframe] = {
        given_any: all_observers.count,
        given_positive: positive_observers.uniq.count,
        given_constructive: constructive_observers.uniq.count
      }
    end
    
    stats
  end

  def calculate_most_observed_stats(observations_relation)
    # Remove any existing order clauses that might conflict with GROUP BY
    base_relation = observations_relation.reorder(nil)
    
    # Find most observed assignment with count
    assignment_results = base_relation
      .joins(:observation_ratings)
      .where(observation_ratings: { rateable_type: 'Assignment' })
      .group('observation_ratings.rateable_id')
      .order('COUNT(observations.id) DESC')
      .limit(2)
      .pluck('observation_ratings.rateable_id', 'COUNT(observations.id)')
    
    most_observed_assignment_id = assignment_results.first&.first
    most_observed_assignment_count = assignment_results.first&.last || 0
    runner_up_assignment_id = assignment_results.second&.first
    runner_up_assignment_count = assignment_results.second&.last || 0
    assignment = most_observed_assignment_id ? Assignment.find_by(id: most_observed_assignment_id) : nil
    runner_up_assignment = runner_up_assignment_id ? Assignment.find_by(id: runner_up_assignment_id) : nil
    
    # Find most observed ability with count
    ability_results = base_relation
      .joins(:observation_ratings)
      .where(observation_ratings: { rateable_type: 'Ability' })
      .group('observation_ratings.rateable_id')
      .order('COUNT(observations.id) DESC')
      .limit(2)
      .pluck('observation_ratings.rateable_id', 'COUNT(observations.id)')
    
    most_observed_ability_id = ability_results.first&.first
    most_observed_ability_count = ability_results.first&.last || 0
    runner_up_ability_id = ability_results.second&.first
    runner_up_ability_count = ability_results.second&.last || 0
    ability = most_observed_ability_id ? Ability.find_by(id: most_observed_ability_id) : nil
    runner_up_ability = runner_up_ability_id ? Ability.find_by(id: runner_up_ability_id) : nil
    
    # Find most observed aspiration with count
    aspiration_results = base_relation
      .joins(:observation_ratings)
      .where(observation_ratings: { rateable_type: 'Aspiration' })
      .group('observation_ratings.rateable_id')
      .order('COUNT(observations.id) DESC')
      .limit(2)
      .pluck('observation_ratings.rateable_id', 'COUNT(observations.id)')
    
    most_observed_aspiration_id = aspiration_results.first&.first
    most_observed_aspiration_count = aspiration_results.first&.last || 0
    runner_up_aspiration_id = aspiration_results.second&.first
    runner_up_aspiration_count = aspiration_results.second&.last || 0
    aspiration = most_observed_aspiration_id ? Aspiration.find_by(id: most_observed_aspiration_id) : nil
    runner_up_aspiration = runner_up_aspiration_id ? Aspiration.find_by(id: runner_up_aspiration_id) : nil
    
    # Find most observed person (observee) with count
    person_results = base_relation
      .joins(observees: :company_teammate)
      .group('teammates.person_id')
      .order('COUNT(observations.id) DESC')
      .limit(2)
      .pluck('teammates.person_id', 'COUNT(observations.id)')
    
    most_observed_person_id = person_results.first&.first
    most_observed_person_count = person_results.first&.last || 0
    runner_up_person_id = person_results.second&.first
    runner_up_person_count = person_results.second&.last || 0
    most_observed_person = most_observed_person_id ? Person.find_by(id: most_observed_person_id) : nil
    runner_up_person = runner_up_person_id ? Person.find_by(id: runner_up_person_id) : nil
    
    # Find most active observer with count
    observer_results = base_relation
      .group('observations.observer_id')
      .order('COUNT(observations.id) DESC')
      .limit(2)
      .pluck('observations.observer_id', 'COUNT(observations.id)')
    
    most_active_observer_id = observer_results.first&.first
    most_active_observer_count = observer_results.first&.last || 0
    runner_up_observer_id = observer_results.second&.first
    runner_up_observer_count = observer_results.second&.last || 0
    most_active_observer = most_active_observer_id ? Person.find_by(id: most_active_observer_id) : nil
    runner_up_observer = runner_up_observer_id ? Person.find_by(id: runner_up_observer_id) : nil
    
    {
      most_observed_assignment: assignment,
      most_observed_assignment_count: most_observed_assignment_count,
      runner_up_assignment: runner_up_assignment,
      runner_up_assignment_count: runner_up_assignment_count,
      most_observed_ability: ability,
      most_observed_ability_count: most_observed_ability_count,
      runner_up_ability: runner_up_ability,
      runner_up_ability_count: runner_up_ability_count,
      most_observed_aspiration: aspiration,
      most_observed_aspiration_count: most_observed_aspiration_count,
      runner_up_aspiration: runner_up_aspiration,
      runner_up_aspiration_count: runner_up_aspiration_count,
      most_observed_person: most_observed_person,
      most_observed_person_count: most_observed_person_count,
      runner_up_person: runner_up_person,
      runner_up_person_count: runner_up_person_count,
      most_active_observer: most_active_observer,
      most_active_observer_count: most_active_observer_count,
      runner_up_observer: runner_up_observer,
      runner_up_observer_count: runner_up_observer_count
    }
  end

  def calculate_received_feedback_stats(published_observations, three_weeks_ago, three_months_ago)
    stats = {}
    
    ['three_weeks', 'three_months', 'all_time'].each do |timeframe|
      scope = published_observations
      
      case timeframe
      when 'three_weeks'
        scope = scope.where('observed_at >= ?', three_weeks_ago)
      when 'three_months'
        scope = scope.where('observed_at >= ?', three_months_ago)
      when 'all_time'
        # No time filter
      end
      
      # Get all observed teammates
      all_observed_teammate_ids = scope.joins(:observees).distinct.pluck('observees.teammate_id').uniq
      
      # Get observations with ratings
      observations_with_ratings = scope.joins(:observees, :observation_ratings).includes(:observees, :observation_ratings).distinct
      
      # Count teammates who received positive/constructive feedback
      positive_teammate_ids = []
      constructive_teammate_ids = []
      
      observations_with_ratings.find_each do |observation|
        has_positive = observation.observation_ratings.positive.any?
        has_negative = observation.observation_ratings.negative.any?
        
        observation.observees.each do |observee|
          if has_positive && !has_negative
            positive_teammate_ids << observee.teammate_id
          elsif has_negative
            constructive_teammate_ids << observee.teammate_id
          end
        end
      end
      
      stats[timeframe] = {
        received_any: all_observed_teammate_ids.count,
        received_positive: positive_teammate_ids.uniq.count,
        received_constructive: constructive_teammate_ids.uniq.count
      }
    end
    
    stats
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
      Observations::AddObserveeService.new(observation: observation, teammate_id: teammate_id).call
    end
  end

  def observation_params
    if params[:observation].present?
      params.require(:observation).permit(
        :story, :privacy_level, :primary_feeling, :secondary_feeling, 
        :observed_at, :custom_slug, :send_notifications, :publishing,
        :observation_type, :created_as_type, :observable_moment_id,
        teammate_ids: [], notify_teammate_ids: [],
        observees_attributes: [:id, :teammate_id, :_destroy],
        observation_ratings_attributes: {},
        story_extras: { gif_urls: [] }
      )
    else
      {}
    end
  end
  
  def load_observable_moment_context(observable_moment)
    template_service = ObservableMoments::ObservationStoryTemplateService.new(observable_moment)
    
    # Pre-fill story
    @observation.story ||= template_service.template
    
    # Pre-fill observees
    if @observation.observees.empty?
      suggested_observees = template_service.suggested_observees
      suggested_observees.each do |teammate|
        @observation.observees.build(teammate: teammate)
      end
    end
    
    # Pre-fill privacy level
    @observation.privacy_level ||= template_service.suggested_privacy_level
    
    # Associate with observable moment
    @observation.observable_moment = observable_moment
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
      Observations::AddObserveeService.new(observation: observation, teammate_id: teammate_id).call
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
    when 'public_to_company'
      '🏢 Public to company'
    when 'public_to_world'
      '🌍 Public to world'
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
      'bi-star-fill'
    when 'agree'
      'bi-hand-thumbs-up'
    when 'na'
      'bi-dash-circle'
    when 'disagree'
      'bi-hand-thumbs-down'
    when 'strongly_disagree'
      'bi-x-circle'
    else
      'bi-question-circle'
    end
  end

  def draft_params
    return {} unless params[:observation].present?
    permitted = params.require(:observation).permit(
      :story, :primary_feeling, :secondary_feeling, :privacy_level,
      :observation_type, :created_as_type, :observable_moment_id,
      observation_ratings_attributes: {},
      story_extras: { gif_urls: [] }
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
    
    # Handle empty gif_urls array - Rails strong params filters out empty arrays by default
    # Check if gif_urls was explicitly set to empty array in original params
    if params[:observation][:story_extras].present?
      original_gif_urls = params[:observation][:story_extras][:gif_urls]
      if original_gif_urls.is_a?(Array) && original_gif_urls.empty?
        # Ensure story_extras hash exists and set empty array
        # Convert to regular hash to allow modification
        permitted[:story_extras] = (permitted[:story_extras] || {}).to_h
        permitted[:story_extras]['gif_urls'] = []
      end
    end
    
    # Convert empty strings to nil for optional fields
    permitted[:secondary_feeling] = nil if permitted[:secondary_feeling].blank?
    permitted[:primary_feeling] = nil if permitted[:primary_feeling].blank?
    
    permitted
  end

  def typed_observation_path_for(observation, options = {})
    path_options = {
      draft_id: observation.id
    }
    path_options[:return_url] = options[:return_url] if options[:return_url].present?
    path_options[:return_text] = options[:return_text] if options[:return_text].present?
    
    case observation.observation_type
    when 'kudos'
      new_kudos_organization_observations_path(organization, path_options)
    when 'feedback'
      new_feedback_organization_observations_path(organization, path_options)
    when 'quick_note'
      new_quick_note_organization_observations_path(organization, path_options)
    else
      new_organization_observation_path(organization, path_options)
    end
  end

  # Helper to determine return_url: params first, then observation show page, then nil
  def determine_return_url
    return params[:return_url] if params[:return_url].present? && params[:return_url] != organization_observations_path(organization)
    return organization_observation_path(organization, @observation) if @observation.present?
    nil
  end

  # Check if return_url should redirect to show page instead
  # Returns true if return_url is nil, edit observation page, or observation index
  def should_redirect_to_show_page?(return_url)
    return true if return_url.blank?
    
    # Check if it's the observation index
    return true if return_url == organization_observations_path(organization)
    
    # Check if it's an edit observation page (new, new_kudos, new_feedback, new_quick_note)
    # Extract the path without query params for comparison
    path_without_params = return_url.split('?').first
    edit_paths = [
      new_organization_observation_path(organization),
      new_kudos_organization_observations_path(organization),
      new_feedback_organization_observations_path(organization),
      new_quick_note_organization_observations_path(organization)
    ]
    
    # Check if the path matches any edit path (with or without query params)
    edit_paths.any? { |edit_path| path_without_params == edit_path.split('?').first }
  end

  def apply_preset_if_selected
    return unless params[:preset].present?
    
    # Check if user has modified any discrete options (if so, ignore preset)
    # For now, we'll apply preset immediately as specified
    preset_params = preset_to_params(params[:preset])
    
    if preset_params
      preset_params.each do |key, value|
        # Only override if the param wasn't explicitly set by user
        # For presets, we override everything
        params[key] = value
      end
    end
  end

  def preset_to_params(preset_name)
    case preset_name.to_s
    when 'kudos'
      {
        view: 'wall',
        spotlight: 'most_observed',
        timeframe: 'last_45_days',
        privacy: ['public_to_company', 'public_to_world']
      }
    else
      nil
    end
  end
end
