# frozen_string_literal: true

class Organizations::DigestController < Organizations::OrganizationNamespaceBaseController
  include DigestHelper

  before_action :authenticate_person!
  before_action :set_teammate
  after_action :verify_authorized

  def edit
    authorize current_user_preferences, :update?
    @user_preference = current_user_preferences
    @about_me_teammates = organization_employees_for_about_me_settings
    @gsd_pending_items_count = GetShitDoneQueryService.new(teammate: @teammate).all_pending_items[:total_pending].to_i
    @return_url = params[:return_url].presence
    @return_text = params[:return_text].presence
    assign_digest_status_presenters
  end

  def sync_all_mediums
    authorize current_user_preferences, :update?
    medium_value = params.require(:value).to_s
    unless %w[off on].include?(medium_value)
      redirect_to organization_start_here_path(@organization), alert: "Invalid digest schedule."
      return
    end

    prefs = current_user_preferences
    prefs.update_preference("digest_slack", medium_value)
    prefs.update_preference("digest_email", medium_value)
    prefs.update_preference("digest_sms", medium_value)
    redirect_to organization_start_here_path(@organization), notice: "Digest channels updated."
  end

  def update
    authorize current_user_preferences, :update?
    prefs = weekly_digest_preferences_for_update
    update_digest_mediums!(prefs)
    update_weekly_digest_toggles!
    update_about_me_days!

    if params[:commit] == 'Save 1:1 day'
      redirect_url = params[:return_url].presence || edit_organization_digest_path(@organization)
      redirect_to redirect_url, notice: 'Digest preferences saved.'
      return
    end

    if params[:return_url].present? && params[:commit].blank?
      if digest_mediums_submitted? && digest_mediums_all_off?(prefs)
        redirect_to params[:return_url],
                    alert: 'No notifications will be sent since no mediums are configured to send notifications to.'
      else
        redirect_to params[:return_url], notice: 'Digest preferences saved.'
      end
      return
    end

    if digest_mediums_submitted? && digest_mediums_all_off?(prefs)
      redirect_to edit_organization_digest_path(@organization, return_url: params[:return_url], return_text: params[:return_text]),
                  alert: 'No notifications will be sent since no mediums are configured to send notifications to.'
    else
      redirect_to edit_organization_digest_path(@organization, return_url: params[:return_url], return_text: params[:return_text]),
                  notice: 'Digest preferences saved.'
    end
  rescue ActiveRecord::RecordInvalid
    @user_preference = current_user_preferences
    @about_me_teammates = organization_employees_for_about_me_settings
    @return_url = params[:return_url].presence
    @return_text = params[:return_text].presence
    assign_digest_status_presenters
    flash.now[:alert] = 'Failed to save digest preferences.'
    render :edit, status: :unprocessable_entity
  end

  private

  def set_teammate
    @teammate = current_company_teammate
  end

  def organization_employees_for_about_me_settings
    direct_report_ids = EmploymentTenure
      .where(company: @organization, manager_teammate: @teammate, ended_at: nil)
      .pluck(:teammate_id)
    target_ids = (direct_report_ids + [@teammate.id]).uniq

    CompanyTeammate
      .where(id: target_ids)
      .employed
      .includes(:person)
      .order('people.last_name ASC, people.first_name ASC')
      .references(:people)
  end

  def assign_digest_status_presenters
    gsd_label = helpers.company_label_for('get_shit_done', 'Get Shit Done')
    teammate_ids = (@about_me_teammates.map(&:id) + [@teammate.id]).uniq
    notifications_by_teammate_id = digest_root_notifications_for_teammates(teammate_ids)

    @digest_status_by_teammate_id = @about_me_teammates.index_by(&:id).transform_values do |employee|
      Digest::TeammateDigestStatusService.new(
        teammate: employee,
        organization: @organization,
        gsd_label: gsd_label,
        gsd_pending_count: employee.id == @teammate.id ? @gsd_pending_items_count : nil,
        recent_notifications: notifications_by_teammate_id[employee.id]
      )
    end
    @gsd_digest_status = @digest_status_by_teammate_id[@teammate.id] ||
      Digest::TeammateDigestStatusService.new(
        teammate: @teammate,
        organization: @organization,
        gsd_label: gsd_label,
        gsd_pending_count: @gsd_pending_items_count,
        recent_notifications: notifications_by_teammate_id[@teammate.id]
      )
  end

  def digest_root_notifications_for_teammates(teammate_ids)
    return {} if teammate_ids.empty?

    Notification
      .where(
        notifiable_type: 'CompanyTeammate',
        notifiable_id: teammate_ids,
        notification_type: Digest::TeammateDigestStatusService::ROOT_DIGEST_TYPES,
        main_thread_id: nil
      )
      .where(created_at: 3.weeks.ago..)
      .order(created_at: :desc)
      .group_by(&:notifiable_id)
  end

  def update_digest_mediums!(prefs)
    if params.key?(:digest_slack)
      value = params[:digest_slack].to_s == 'on' ? 'on' : 'off'
      prefs.update_preference('digest_slack', value)
    end
    if params.key?(:digest_email)
      value = params[:digest_email].to_s == 'on' ? 'on' : 'off'
      prefs.update_preference('digest_email', value)
    end
    if params.key?(:digest_sms)
      value = params[:digest_sms].to_s == 'on' ? 'on' : 'off'
      prefs.update_preference('digest_sms', value)
    end
  end

  def digest_mediums_submitted?
    params.key?(:digest_slack) || params.key?(:digest_email) || params.key?(:digest_sms)
  end

  def digest_mediums_all_off?(prefs)
    prefs.effective_digest_slack(nil) != 'on' && prefs.effective_digest_sms(nil) != 'on'
  end

  def update_weekly_digest_toggles!
    prefs = weekly_digest_preferences_for_update

    if params.key?(:about_me_digest_enabled)
      value = params[:about_me_digest_enabled].to_s == 'on' ? 'on' : 'off'
      prefs.update_preference('about_me_digest_enabled', value)
    end
    if params.key?(:one_on_one_digest_enabled)
      value = params[:one_on_one_digest_enabled].to_s == 'on' ? 'on' : 'off'
      prefs.update_preference('one_on_one_digest_enabled', value)
    end
  end

  def weekly_digest_preferences_for_update
    teammate = weekly_digest_teammate_from_params
    return current_user_preferences unless teammate

    authorize teammate, :update?, policy_class: CompanyTeammatePolicy
    UserPreference.for_person(teammate.person)
  end

  def weekly_digest_teammate_from_params
    return nil if params[:digest_teammate_id].blank?

    CompanyTeammate.find_by(id: params[:digest_teammate_id], organization: @organization)
  end

  def update_about_me_days!
    about_me_days = params[:about_me_days]
    return unless about_me_days.is_a?(ActionController::Parameters) || about_me_days.is_a?(Hash)

    permitted_days = about_me_days.respond_to?(:permit!) ? about_me_days.permit!.to_h : about_me_days.to_h
    permitted_days.each do |teammate_id, raw_day|
      teammate = CompanyTeammate.find_by(id: teammate_id, organization: @organization)
      next unless teammate
      authorize teammate, :update?, policy_class: CompanyTeammatePolicy

      day = normalize_about_me_weekly_day(raw_day)
      next if day.nil?

      UserPreference.for_person(teammate.person).update_preference('about_me_weekly_day', day)
    end
  end

  def normalize_about_me_weekly_day(raw_day)
    value = raw_day.to_s
    return 'off' if value == 'off'
    return value if value.match?(/\A[0-6]\z/)

    nil
  end

  public

  def send_gsd_test
    authorize current_user_preferences, :update?
    if GetShitDoneQueryService.new(teammate: @teammate).all_pending_items[:total_pending].to_i.zero?
      redirect_to edit_organization_digest_path(@organization, return_url: params[:return_url], return_text: params[:return_text]),
                  alert: 'No test sent. Add an item to your Get Shit Done list, then send a test.'
      return
    end

    Digest::SendDigestJob.perform_later(@teammate.id)
    redirect_to edit_organization_digest_path(@organization, return_url: params[:return_url], return_text: params[:return_text]),
                notice: 'GSD test notification queued and should be delivered shortly.'
  end

  def send_about_me_test
    authorize current_user_preferences, :update?
    teammate = CompanyTeammate.find_by(id: params[:teammate_id], organization: @organization)
    unless teammate
      redirect_to edit_organization_digest_path(@organization), alert: 'Could not find teammate for About Me digest test.'
      return
    end
    authorize teammate, :update?, policy_class: CompanyTeammatePolicy

    Digest::SendAboutMeJob.perform_later(teammate.id)
    redirect_to edit_organization_digest_path(@organization, return_url: params[:return_url], return_text: params[:return_text]),
                notice: "About Me digest test queued for #{teammate.person.casual_name}."
  end

  def send_one_on_one_test
    authorize current_user_preferences, :update?
    teammate = CompanyTeammate.find_by(id: params[:teammate_id], organization: @organization)
    unless teammate
      redirect_to edit_organization_digest_path(@organization), alert: 'Could not find teammate for 1:1 digest test.'
      return
    end
    authorize teammate, :update?, policy_class: CompanyTeammatePolicy

    Digest::SendOneOnOneDigestJob.perform_later(teammate.id)
    redirect_to edit_organization_digest_path(@organization, return_url: params[:return_url], return_text: params[:return_text]),
                notice: "1:1 digest test queued for #{teammate.person.casual_name}."
  end

  def send_weekly_digests_now
    authorize current_user_preferences, :update?
    teammate = CompanyTeammate.find_by(id: params[:teammate_id], organization: @organization)
    redirect_target = params[:return_url].presence || edit_organization_digest_path(@organization)

    unless teammate
      redirect_to redirect_target, alert: 'Could not find teammate for weekly digest send.'
      return
    end
    authorize teammate, :update?, policy_class: CompanyTeammatePolicy

    prefs = UserPreference.for_person(teammate.person)
    one_on_one_on = weekly_digest_enabled_in_prefs?(prefs, :one_on_one_digest_enabled)
    about_me_on = weekly_digest_enabled_in_prefs?(prefs, :about_me_digest_enabled)

    unless one_on_one_on || about_me_on
      redirect_to redirect_target,
                  alert: 'Select at least one weekly digest (1:1 guide or About Me reminder) before sending.'
      return
    end

    Digest::SendOneOnOneDigestJob.perform_later(teammate.id) if one_on_one_on
    Digest::SendAboutMeJob.perform_later(teammate.id) if about_me_on

    labels = []
    labels << '1:1 guide' if one_on_one_on
    labels << 'About Me reminder' if about_me_on
    notice = "Queued #{labels.join(' and ')} for #{teammate.person.casual_name}. They should arrive in Slack shortly."

    redirect_to redirect_target, notice: notice
  end
end
