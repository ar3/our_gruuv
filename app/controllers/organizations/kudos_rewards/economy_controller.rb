# frozen_string_literal: true

class Organizations::KudosRewards::EconomyController < Organizations::KudosRewards::BaseController
  DEFAULT_ECONOMY_CONFIG = {
    'ability_milestone' => { 'points_to_give' => '250', 'points_to_spend' => '250' },
    'seat_change' => { 'points_to_give' => '250', 'points_to_spend' => '250' },
    'check_in_completed' => { 'points_to_give' => '250', 'points_to_spend' => '250' },
    'goal_check_in' => { 'points_to_give' => '100', 'points_to_spend' => '100' },
    'birthday' => { 'points_to_give' => '250', 'points_to_spend' => '250' },
    'work_anniversary' => { 'points_to_give' => '250', 'points_to_spend' => '250' },
    'weekly_guaranteed_minimum_to_give' => '100',
    'peer_to_peer_rating_limits' => {
      'exceptional_ratings_min' => '30',
      'exceptional_ratings_max' => '50',
      'solid_ratings_min' => '5',
      'solid_ratings_max' => '25'
    }
  }.freeze

  before_action :authorize_view_dashboard!, only: [:show, :edit]
  before_action :authorize_manage_rewards!, only: [:update]

  def show
    redirect_to edit_organization_kudos_rewards_economy_path(organization)
  end

  def edit
    @organization = organization
    @config = economy_config_with_defaults
    @economy_return_url = params[:return_url].presence
    @economy_return_text = params[:return_text].presence
  end

  def update
    @organization = organization
    if @organization.update(kudos_points_economy_config: economy_config_from_params)
      flash[:notice] = "Economy settings saved."
      redirect_to edit_organization_kudos_rewards_economy_path(organization)
    else
      @config = economy_config_with_defaults
      @economy_return_url = params[:return_url].presence
      @economy_return_text = params[:return_text].presence
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def authorize_view_dashboard!
    authorize :kudos, :view_dashboard?
  end

  def authorize_manage_rewards!
    authorize :kudos, :manage_rewards?
  end

  def economy_config_with_defaults
    saved = organization.kudos_points_economy_config || {}
    DEFAULT_ECONOMY_CONFIG.deep_merge(saved)
  end

  def economy_config_from_params
    permitted = params.permit(
      economy: [
        :disable_kudos_points,
        { ability_milestone: [:points_to_give, :points_to_spend] },
        { seat_change: [:points_to_give, :points_to_spend] },
        { check_in_completed: [:points_to_give, :points_to_spend] },
        { goal_check_in: [:points_to_give, :points_to_spend] },
        { birthday: [:points_to_give, :points_to_spend] },
        { work_anniversary: [:points_to_give, :points_to_spend] },
        { bank_automation: [:weekly_guaranteed_minimum_to_give] },
        { peer_to_peer_rating_limits: [:exceptional_ratings_min, :exceptional_ratings_max, :solid_ratings_min, :solid_ratings_max] }
      ]
    )
    raw = permitted[:economy] || {}
    config = {}
    # Checkbox + hidden field can send array ["0", "1"] when checked; take last value
    disable_val = raw[:disable_kudos_points]
    disable_val = disable_val.last if disable_val.is_a?(Array)
    config['disable_kudos_points'] = ActiveModel::Type::Boolean.new.cast(disable_val) ? 'true' : 'false'

    %w[ability_milestone seat_change check_in_completed goal_check_in birthday work_anniversary].each do |key|
      next unless raw[key].present?
      config[key] = {
        'points_to_give' => raw[key][:points_to_give].presence,
        'points_to_spend' => raw[key][:points_to_spend].presence
      }.compact
    end

    if raw[:bank_automation].present? && raw[:bank_automation][:weekly_guaranteed_minimum_to_give].present?
      config['weekly_guaranteed_minimum_to_give'] = raw[:bank_automation][:weekly_guaranteed_minimum_to_give]
    end

    if raw[:peer_to_peer_rating_limits].present?
      limits = raw[:peer_to_peer_rating_limits].permit(:exceptional_ratings_min, :exceptional_ratings_max, :solid_ratings_min, :solid_ratings_max).to_h.compact
      if limits.any?
        config['peer_to_peer_rating_limits'] = limits.transform_keys(&:to_s)
      end
    end

    config
  end
end
