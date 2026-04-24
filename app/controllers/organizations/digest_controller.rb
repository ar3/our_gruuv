# frozen_string_literal: true

class Organizations::DigestController < Organizations::OrganizationNamespaceBaseController
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
    slack = params[:digest_slack].to_s == 'on' ? 'on' : 'off'
    email = params[:digest_email].to_s == 'on' ? 'on' : 'off'
    sms = params[:digest_sms].to_s == 'on' ? 'on' : 'off'

    current_user_preferences.update_preference('digest_slack', slack)
    current_user_preferences.update_preference('digest_email', email)
    current_user_preferences.update_preference('digest_sms', sms)
    update_about_me_days!

    if params[:commit] == 'Save 1:1 day'
      redirect_url = params[:return_url].presence || edit_organization_digest_path(@organization)
      redirect_to redirect_url, notice: 'Digest preferences saved.'
      return
    end

    if params[:return_url].present? && params[:commit].blank?
      if slack == 'off' && sms == 'off'
        redirect_to params[:return_url],
                    alert: 'No notifications will be sent since no mediums are configured to send notifications to.'
      else
        redirect_to params[:return_url], notice: 'Digest preferences saved.'
      end
      return
    end

    if slack == 'off' && sms == 'off'
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
      redirect_to edit_organization_digest_path(@organization), alert: 'Could not find teammate for 1:1 test.'
      return
    end

    Digest::SendAboutMeJob.perform_later(teammate.id)
    redirect_to edit_organization_digest_path(@organization, return_url: params[:return_url], return_text: params[:return_text]),
                notice: "1:1 digest test queued for #{teammate.person.casual_name}."
  end
end
