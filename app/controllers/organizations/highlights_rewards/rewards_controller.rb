# Controller for managing the rewards catalog (admin only)
class Organizations::HighlightsRewards::RewardsController < Organizations::HighlightsRewards::BaseController
  before_action :set_reward, only: [:show, :edit, :update, :destroy, :restore]
  before_action :authorize_management!, except: [:index, :show]

  def index
    authorize :highlights, :view_rewards_catalog?

    @rewards = organization.highlights_rewards
      .where(deleted_at: nil)
      .order(active: :desc, cost_in_points: :asc)

    @inactive_rewards = organization.highlights_rewards
      .where.not(deleted_at: nil)
      .or(organization.highlights_rewards.where(active: false))
      .order(updated_at: :desc)
      .limit(10) if policy(:highlights).manage_rewards_catalog?
  end

  def show
    authorize :highlights, :view_rewards_catalog?
  end

  def new
    @reward = organization.highlights_rewards.build(
      reward_type: 'gift_card',
      active: true
    )
  end

  def create
    @reward = organization.highlights_rewards.build(reward_params)

    if @reward.save
      flash[:notice] = "Reward '#{@reward.name}' created successfully."
      redirect_to organization_highlights_rewards_rewards_path(organization)
    else
      flash.now[:alert] = @reward.errors.full_messages.join(', ')
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @reward.update(reward_params)
      flash[:notice] = "Reward '#{@reward.name}' updated successfully."
      redirect_to organization_highlights_rewards_rewards_path(organization)
    else
      flash.now[:alert] = @reward.errors.full_messages.join(', ')
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @reward.soft_delete!
    flash[:notice] = "Reward '#{@reward.name}' has been archived."
    redirect_to organization_highlights_rewards_rewards_path(organization)
  end

  def restore
    @reward.update!(deleted_at: nil, active: true)
    flash[:notice] = "Reward '#{@reward.name}' has been restored."
    redirect_to organization_highlights_rewards_rewards_path(organization)
  end

  private

  def set_reward
    @reward = organization.highlights_rewards.find(params[:id])
  end

  def authorize_management!
    authorize :highlights, :manage_rewards_catalog?
  end

  def reward_params
    params.require(:highlights_reward).permit(
      :name,
      :description,
      :cost_in_points,
      :reward_type,
      :active,
      :image_url
    )
  end
end
