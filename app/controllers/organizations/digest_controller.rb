# frozen_string_literal: true

class Organizations::DigestController < Organizations::OrganizationNamespaceBaseController
  before_action :authenticate_person!
  before_action :set_teammate
  after_action :verify_authorized

  def edit
    authorize current_user_preferences, :update?
    @user_preference = current_user_preferences
    @return_url = params[:return_url].presence
    @return_text = params[:return_text].presence
  end

  def sync_all_mediums
    authorize current_user_preferences, :update?
    freq = params.require(:frequency).to_s
    unless %w[off weekly daily].include?(freq)
      redirect_to organization_start_here_path(@organization), alert: "Invalid digest schedule."
      return
    end

    prefs = current_user_preferences
    prefs.update_preference("digest_slack", freq)
    prefs.update_preference("digest_email", freq)
    prefs.update_preference("digest_sms", freq)
    redirect_to organization_start_here_path(@organization), notice: "Digest schedule updated for all channels."
  end

  def update
    authorize current_user_preferences, :update?

    current_user_preferences.update_preference('digest_slack', params[:digest_slack].presence) if params.key?(:digest_slack)
    current_user_preferences.update_preference('digest_email', params[:digest_email].presence || 'off')
    current_user_preferences.update_preference('digest_sms', params[:digest_sms].presence || 'off')
    if params.key?(:digest_weekly_day) && params[:digest_weekly_day].to_s.match?(/\A[0-6]\z/)
      current_user_preferences.update_preference('digest_weekly_day', params[:digest_weekly_day])
    end

    if params[:commit] == 'Save and Test By Sending Now'
      Digest::SendDigestJob.perform_later(@teammate.id)
      redirect_to edit_organization_digest_path(@organization, return_url: params[:return_url], return_text: params[:return_text]),
                  notice: 'Digests have been queued to send and should be delivered in the next minute or so.'
    else
      redirect_url = params[:return_url].presence || about_me_organization_company_teammate_path(@organization, @teammate)
      redirect_to redirect_url, notice: 'Digest preferences saved.'
    end
  rescue ActiveRecord::RecordInvalid
    @user_preference = current_user_preferences
    @return_url = params[:return_url].presence
    @return_text = params[:return_text].presence
    flash.now[:alert] = 'Failed to save digest preferences.'
    render :edit, status: :unprocessable_entity
  end

  private

  def set_teammate
    @teammate = current_company_teammate
  end
end
