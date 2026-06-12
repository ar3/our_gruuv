# frozen_string_literal: true

# Notifications tab on the profile page. Teammate-scoped so a manager (or admin) can
# administer a teammate's notification preferences. Controls auto-save via small forms.
class Organizations::CompanyTeammates::NotificationsController < Organizations::OrganizationNamespaceBaseController
  include DigestHelper
  include Organizations::AssignsViewableTeammates

  before_action :authenticate_person!
  before_action :set_teammate
  before_action :authorize_teammate!
  after_action :verify_authorized

  def show
    assign_viewable_teammates_context!(selected_teammate: @teammate)
    @user_preference = UserPreference.for_person(@teammate.person)
    @gsd_pending_items_count = GetShitDoneQueryService.new(teammate: @teammate).all_pending_items[:total_pending].to_i
    @interesting_pending_count = SomethingInterestingQueryService.new(
      teammate: @teammate,
      since: SomethingInterestingQueryService.baseline(@teammate)
    ).total_count
    @digest_status = Digest::TeammateDigestStatusService.new(
      teammate: @teammate,
      organization: @organization,
      gsd_label: helpers.company_label_for('get_shit_done', 'Get Shit Done'),
      gsd_pending_count: @gsd_pending_items_count,
      interesting_pending_count: @interesting_pending_count
    )
    @direct_reports = direct_reports_of(@teammate)
  end

  def update
    prefs = UserPreference.for_person(@teammate.person)

    update_toggle!(prefs, :gsd_digest_enabled)
    update_toggle!(prefs, :interesting_things_digest_enabled)
    update_toggle!(prefs, :one_on_one_digest_enabled)
    update_toggle!(prefs, :about_me_digest_enabled)
    update_toggle!(prefs, :digest_sms)
    update_weekly_day!(prefs)

    redirect_to notifications_path_for(@teammate), notice: 'Notification preferences saved.'
  end

  def send_gsd_test
    if GetShitDoneQueryService.new(teammate: @teammate).all_pending_items[:total_pending].to_i.zero?
      redirect_to notifications_path_for(@teammate),
                  alert: "No test sent. Add an item to the #{gsd_label} list, then send a test."
      return
    end

    Digest::SendDigestJob.perform_later(@teammate.id)
    redirect_to notifications_path_for(@teammate),
                notice: "#{gsd_label} test notification queued and should be delivered shortly."
  end

  def send_interesting_things_test
    since = SomethingInterestingQueryService.baseline(@teammate)
    if SomethingInterestingQueryService.new(teammate: @teammate, since: since).total_count.zero?
      redirect_to notifications_path_for(@teammate),
                  alert: 'No test sent. There is nothing new on the Interesting Things page to show.'
      return
    end

    Digest::SendInterestingThingsJob.perform_later(@teammate.id)
    redirect_to notifications_path_for(@teammate),
                notice: 'Interesting Things test notification queued and should be delivered shortly.'
  end

  def send_about_me_test
    Digest::SendAboutMeJob.perform_later(@teammate.id)
    redirect_to notifications_path_for(@teammate),
                notice: "About Me digest test queued for #{@teammate.person.casual_name}."
  end

  def send_one_on_one_test
    Digest::SendOneOnOneDigestJob.perform_later(@teammate.id)
    redirect_to notifications_path_for(@teammate),
                notice: "1:1 digest test queued for #{@teammate.person.casual_name}."
  end

  def send_weekly_digests_now
    prefs = UserPreference.for_person(@teammate.person)
    one_on_one_on = prefs.weekly_digest_enabled?(:one_on_one_digest_enabled)
    about_me_on = prefs.weekly_digest_enabled?(:about_me_digest_enabled)

    unless one_on_one_on || about_me_on
      redirect_to notifications_path_for(@teammate),
                  alert: 'Select at least one weekly digest (1:1 guide or About Me reminder) before sending.'
      return
    end

    Digest::SendOneOnOneDigestJob.perform_later(@teammate.id) if one_on_one_on
    Digest::SendAboutMeJob.perform_later(@teammate.id) if about_me_on

    labels = []
    labels << '1:1 guide' if one_on_one_on
    labels << 'About Me reminder' if about_me_on
    redirect_to notifications_path_for(@teammate),
                notice: "Queued #{labels.join(' and ')} for #{@teammate.person.casual_name}. They should arrive in Slack shortly."
  end

  private

  def set_teammate
    @teammate = find_organization_teammate!(params[:company_teammate_id], scope: organization.teammates.includes(:person))
  end

  def authorize_teammate!
    authorize @teammate, :update?, policy_class: CompanyTeammatePolicy
  end

  def notifications_path_for(teammate)
    organization_company_teammate_notifications_path(@organization, teammate)
  end

  def gsd_label
    helpers.company_label_for('get_shit_done', 'Get Shit Done')
  end

  def update_toggle!(prefs, key)
    return unless params.key?(key)

    value = params[key].to_s == 'on' ? 'on' : 'off'
    prefs.update_preference(key.to_s, value)
  end

  def update_weekly_day!(prefs)
    raw_day = params.dig(:about_me_days, @teammate.id.to_s)
    return if raw_day.nil?

    day = normalize_weekly_day(raw_day)
    return if day.nil?

    prefs.update_preference('about_me_weekly_day', day)
  end

  def normalize_weekly_day(raw_day)
    value = raw_day.to_s
    return 'off' if value == 'off'
    return value if value.match?(/\A[0-6]\z/)

    nil
  end

  def direct_reports_of(teammate)
    report_ids = EmploymentTenure
      .where(company: @organization, manager_teammate: teammate, ended_at: nil)
      .distinct
      .pluck(:teammate_id)
    return CompanyTeammate.none if report_ids.empty?

    CompanyTeammate
      .where(id: report_ids)
      .employed
      .includes(:person)
      .order('people.last_name ASC, people.first_name ASC')
      .references(:people)
  end
end
