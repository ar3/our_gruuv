class Organizations::CompanyPreferencesController < Organizations::OrganizationNamespaceBaseController
  before_action :set_company
  after_action :verify_authorized

  CLARITY_THRESHOLD_KEYS = [
    EngagementHealth::Thresholds::REQUIRED_CLARITY_HEALTHY_WITHIN_DAYS_KEY,
    EngagementHealth::Thresholds::REQUIRED_CLARITY_NEEDS_ATTENTION_AT_DAYS_KEY
  ].freeze

  def edit
    authorize @company, :view_company_preferences?
    @preferences = load_preferences
  end

  def update
    authorize @company, :customize_company?

    unless update_job_description_hr_defaults
      @preferences = load_preferences
      flash.now[:alert] = @company.errors.full_messages.to_sentence.presence || 'Failed to update job description defaults.'
      render :edit, status: :unprocessable_entity
      return
    end

    update_observable_moment_notifier
    unless apply_logo_update
      @preferences = load_preferences
      flash.now[:alert] = @logo_update_error.presence || 'Could not update company logo.'
      render :edit, status: :unprocessable_entity
      return
    end

    clarity_error = required_clarity_threshold_error
    if clarity_error
      @preferences = load_preferences.merge(submitted_clarity_preferences)
      flash.now[:alert] = clarity_error
      render :edit, status: :unprocessable_entity
      return
    end

    clarity_changed = clarity_thresholds_changing?
    if update_preferences
      enqueue_engagement_health_refresh_for_company! if clarity_changed
      notice = if clarity_changed
        'Company preferences updated successfully. Gruuv Health is rebuilding for this company.'
      else
        'Company preferences updated successfully.'
      end
      redirect_to edit_organization_company_preference_path(@organization), notice: notice
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
      'prompt' => @company.company_label_preferences.find_by(label_key: 'prompt')&.label_value || '',
      'kudos_point' => @company.company_label_preferences.find_by(label_key: 'kudos_point')&.label_value || '',
      'get_shit_done' => @company.company_label_preferences.find_by(label_key: 'get_shit_done')&.label_value || '',
      Organization::ACKNOWLEDGEMENT_EXPLANATION_LABEL_KEY => acknowledgement_explanation_for_form,
      EngagementHealth::Thresholds::REQUIRED_CLARITY_HEALTHY_WITHIN_DAYS_KEY =>
        preference_value(EngagementHealth::Thresholds::REQUIRED_CLARITY_HEALTHY_WITHIN_DAYS_KEY),
      EngagementHealth::Thresholds::REQUIRED_CLARITY_NEEDS_ATTENTION_AT_DAYS_KEY =>
        preference_value(EngagementHealth::Thresholds::REQUIRED_CLARITY_NEEDS_ATTENTION_AT_DAYS_KEY)
    }
  end

  def preference_value(key)
    @company.company_label_preferences.find_by(label_key: key)&.label_value || ''
  end

  def acknowledgement_explanation_for_form
    @company.label_for(
      Organization::ACKNOWLEDGEMENT_EXPLANATION_LABEL_KEY,
      Organization::ACKNOWLEDGEMENT_EXPLANATION_DEFAULT
    )
  end

  def update_job_description_hr_defaults
    return true if params[:organization].blank?
    return true unless job_description_hr_params_present?

    permitted = params.require(:organization).permit(
      :job_description_disclaimer,
      :work_environment,
      :physical_requirements,
      :travel
    )
    @company.assign_attributes(permitted)
    @company.save
  end

  def job_description_hr_params_present?
    org = params[:organization]
    %w[job_description_disclaimer work_environment physical_requirements travel].any? do |key|
      org.key?(key) || org.key?(key.to_sym)
    end
  end

  def update_observable_moment_notifier
    return if params[:organization].blank?
    # Avoid clearing the notifier when the form omits this key (e.g. tests or partial updates).
    org = params[:organization]
    return unless org.key?(:observable_moment_notifier_teammate_id) || org.key?('observable_moment_notifier_teammate_id')

    permitted = params.require(:organization).permit(:observable_moment_notifier_teammate_id)
    raw = permitted[:observable_moment_notifier_teammate_id].to_s.presence
    new_id = raw.present? ? raw.to_i : nil
    if new_id.present?
      teammate = @company.teammates.find_by(id: new_id)
      @company.observable_moment_notifier_teammate_id = teammate&.id
    else
      @company.observable_moment_notifier_teammate_id = nil
    end
    @company.save!
  end

  def update_preferences
    success = true

    params[:preferences]&.each do |key, value|
      preference = @company.company_label_preferences.find_or_initialize_by(label_key: key.to_s)

      # Handle boolean preferences (checkboxes)
      # Rails checkboxes send 'true' when checked, 'false' when unchecked (via hidden field)
      if key.to_s == Organization::ACKNOWLEDGEMENT_EXPLANATION_LABEL_KEY
        if acknowledgement_explanation_blank_or_default?(value)
          preference.destroy if preference.persisted?
        else
          preference.label_value = value
          unless preference.save
            success = false
          end
        end
      elsif value.present?
        preference.label_value = value.to_s.strip
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

  def acknowledgement_explanation_blank_or_default?(value)
    normalized = value.to_s.strip
    normalized.blank? || normalized == Organization::ACKNOWLEDGEMENT_EXPLANATION_DEFAULT
  end

  def submitted_clarity_preferences
    prefs = params[:preferences] || {}
    CLARITY_THRESHOLD_KEYS.index_with { |key| prefs[key].to_s }
  end

  def clarity_thresholds_changing?
    return false if params[:preferences].blank?

    CLARITY_THRESHOLD_KEYS.any? do |key|
      next false unless params[:preferences].key?(key) || params[:preferences].key?(key.to_sym)

      incoming = params[:preferences][key].to_s.strip
      current = preference_value(key).to_s.strip
      incoming != current
    end
  end

  # Returns an error message when submitted Healthy/Needs Attention violate
  # early < healthy < needs_attention. Blank fields mean "use default".
  def required_clarity_threshold_error
    prefs = params[:preferences]
    return nil if prefs.blank?

    healthy_key = EngagementHealth::Thresholds::REQUIRED_CLARITY_HEALTHY_WITHIN_DAYS_KEY
    needs_key = EngagementHealth::Thresholds::REQUIRED_CLARITY_NEEDS_ATTENTION_AT_DAYS_KEY
    return nil unless prefs.key?(healthy_key) || prefs.key?(needs_key) ||
                      prefs.key?(healthy_key.to_sym) || prefs.key?(needs_key.to_sym)

    healthy = parse_optional_positive_int(prefs[healthy_key])
    needs = parse_optional_positive_int(prefs[needs_key])
    return 'Healthy within and Needs Attention at must be whole positive numbers when set.' if healthy == :invalid || needs == :invalid

    healthy ||= EngagementHealth::Thresholds::REQUIRED_CLARITY_HEALTHY_WITHIN_DAYS
    needs ||= EngagementHealth::Thresholds::REQUIRED_CLARITY_NEEDS_ATTENTION_AT_DAYS
    early = EngagementHealth::Thresholds::CHECK_IN_EARLY_WITHIN_DAYS

    unless early < healthy && healthy < needs
      return "Required Clarity windows must satisfy #{early} < Healthy < Needs Attention (got Healthy=#{healthy}, Needs Attention=#{needs})."
    end

    nil
  end

  def parse_optional_positive_int(value)
    return nil if value.blank?

    int = Integer(value.to_s.strip)
    return :invalid unless int.positive?

    int
  rescue ArgumentError, TypeError
    :invalid
  end

  def enqueue_engagement_health_refresh_for_company!
    teammate_ids = CompanyTeammate.employed.where(organization: @company).pluck(:id)
    return if teammate_ids.empty?

    # Batch via existing live-cache backfill (concurrency-limited per org).
    teammate_ids.each_slice(100) do |slice|
      EngagementHealthLiveCacheBackfillJob.perform_later(@company.id, slice)
    end
  end

  def apply_logo_update
    @logo_update_error = nil
    return true if params[:organization].blank?

    permitted = params.require(:organization).permit(:logo, :remove_logo)
    if ActiveModel::Type::Boolean.new.cast(permitted[:remove_logo])
      @company.logo.purge
      return true
    end
    return true if permitted[:logo].blank?

    uploaded_logo = permitted[:logo]
    original_filename = uploaded_logo.original_filename.to_s
    extension = File.extname(original_filename).presence || '.png'
    s3_key = "company_logos/#{@company.id}/#{SecureRandom.uuid}#{extension.downcase}"
    uploaded_logo.tempfile.rewind if uploaded_logo.respond_to?(:tempfile)
    @company.logo.attach(
      io: uploaded_logo.tempfile,
      filename: original_filename.presence || "company-logo#{extension.downcase}",
      content_type: uploaded_logo.content_type,
      key: s3_key
    )
    return true if @company.valid?

    @logo_update_error = @company.errors.full_messages_for(:logo).presence&.to_sentence
    @company.logo.purge
    @company.reload
    false
  end
end
