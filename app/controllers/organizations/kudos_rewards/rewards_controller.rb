# Controller for managing the rewards catalog (admin only)
class Organizations::KudosRewards::RewardsController < Organizations::KudosRewards::BaseController
  before_action :set_reward, only: [:show, :edit, :update, :destroy, :restore]
  before_action :authorize_management!, except: [:index, :show]

  def index
    authorize :kudos, :view_rewards_catalog?

    @rewards = organization.kudos_rewards
      .active
      .order(cost_in_points: :asc)

    @inactive_rewards = organization.kudos_rewards
      .where.not(deleted_at: nil)
      .or(organization.kudos_rewards.where(active: false))
      .order(updated_at: :desc)
      .limit(10) if policy(:kudos).manage_rewards_catalog?

    @rewards_return_url = params[:return_url].presence
    @rewards_return_text = params[:return_text].presence
  end

  def show
    authorize :kudos, :view_rewards_catalog?

    @rewards_return_url = params[:return_url].presence
    @rewards_return_text = params[:return_text].presence
  end

  def new
    @reward = organization.kudos_rewards.build(
      reward_type: 'gift_card',
      active: true
    )
  end

  def create
    @reward = organization.kudos_rewards.build(reward_params.except(:image))

    if params[:kudos_reward].present? && params[:kudos_reward][:image].present?
      begin
        uploader = S3::ImageUploader.new
        @reward.image_url = uploader.upload(params[:kudos_reward][:image], folder: 'rewards')
      rescue => e
        @reward.errors.add(:image, "failed to upload: #{e.message}")
        flash.now[:alert] = @reward.errors.full_messages.join(', ')
        render :new, status: :unprocessable_entity
        return
      end
    end

    if @reward.save
      flash[:notice] = "Reward '#{@reward.name}' created successfully."
      redirect_to organization_kudos_rewards_rewards_path(organization)
    else
      flash.now[:alert] = @reward.errors.full_messages.join(', ')
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    update_params = reward_params.except(:image)

    if params[:kudos_reward].present? && params[:kudos_reward][:image].present?
      begin
        uploader = S3::ImageUploader.new
        update_params[:image_url] = uploader.upload(params[:kudos_reward][:image], folder: 'rewards')
      rescue => e
        @reward.errors.add(:image, "failed to upload: #{e.message}")
        flash.now[:alert] = @reward.errors.full_messages.join(', ')
        render :edit, status: :unprocessable_entity
        return
      end
    end

    if @reward.update(update_params)
      flash[:notice] = "Reward '#{@reward.name}' updated successfully."
      redirect_to organization_kudos_rewards_rewards_path(organization)
    else
      flash.now[:alert] = @reward.errors.full_messages.join(', ')
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @reward.soft_delete!
    flash[:notice] = "Reward '#{@reward.name}' has been archived."
    redirect_to organization_kudos_rewards_rewards_path(organization)
  end

  def restore
    @reward.update!(deleted_at: nil, active: true)
    flash[:notice] = "Reward '#{@reward.name}' has been restored."
    redirect_to organization_kudos_rewards_rewards_path(organization)
  end

  private

  def set_reward
    @reward = organization.kudos_rewards.find(params[:id])
  end

  def authorize_management!
    authorize :kudos, :manage_rewards_catalog?
  end

  def reward_params
    params.require(:kudos_reward).permit(
      :name,
      :description,
      :cost_in_points,
      :reward_type,
      :active,
      :image_url,
      :image
    )
  end
end
