# Controller for managing reward redemptions
class Organizations::KudosRewards::RedemptionsController < Organizations::KudosRewards::BaseController
  before_action :set_redemption, only: [:show, :fulfill, :cancel]
  before_action :authorize_status_management!, only: [:fulfill, :cancel]

  # List redemptions - own or all (admin)
  def index
    if policy(:kudos).view_all_redemptions?
      # Admin view - show all redemptions
      authorize :kudos, :view_all_redemptions?
      redemptions_scope = organization.kudos_redemptions
        .includes(:company_teammate, :kudos_reward)
        .recent
      total_count = redemptions_scope.count
      @pagy = Pagy.new(count: total_count, page: params[:page] || 1, items: 25)
      @redemptions = redemptions_scope.limit(@pagy.items).offset(@pagy.offset)
      @view_mode = :admin
    else
      # User view - show own redemptions
      authorize :kudos, :view_own_redemptions?
      redemptions_scope = current_company_teammate.kudos_redemptions
        .includes(:kudos_reward)
        .recent
      total_count = redemptions_scope.count
      @pagy = Pagy.new(count: total_count, page: params[:page] || 1, items: 25)
      @redemptions = redemptions_scope.limit(@pagy.items).offset(@pagy.offset)
      @view_mode = :user
    end
  end

  # Show redemption details
  def show
    authorize_view!
  end

  # Form to redeem a specific reward
  def new
    authorize :kudos, :redeem_reward?

    @reward = organization.kudos_rewards.active.find(params[:reward_id])
    @ledger = current_company_teammate.kudos_ledger
    @can_afford = @ledger.can_spend?(@reward.cost_in_points)
  end

  # Process redemption
  def create
    authorize :kudos, :redeem_reward?

    @reward = organization.kudos_rewards.active.find(redemption_params[:reward_id])

    result = Kudos::RedeemRewardService.call(
      company_teammate: current_company_teammate,
      reward: @reward,
      notes: redemption_params[:notes]
    )

    if result.ok?
      flash[:notice] = "Successfully redeemed #{@reward.name} for #{@reward.cost_in_points.to_i} points!"
      redirect_to organization_kudos_rewards_redemption_path(organization, result.value[:redemption])
    else
      flash[:alert] = result.error
      redirect_to organization_kudos_rewards_rewards_path(organization)
    end
  end

  # Admin: Mark redemption as fulfilled
  def fulfill
    external_ref = params[:external_reference]

    begin
      @redemption.mark_fulfilled!(external_ref: external_ref)
      flash[:notice] = "Redemption marked as fulfilled."
    rescue KudosRedemption::InvalidStateTransition => e
      flash[:alert] = "Cannot fulfill this redemption: #{e.message}"
    end

    redirect_to organization_kudos_rewards_redemption_path(organization, @redemption)
  end

  # Admin: Cancel redemption and refund points
  def cancel
    reason = params[:reason] || "Cancelled by admin"

    begin
      ApplicationRecord.transaction do
        @redemption.mark_cancelled!(reason: reason)

        # Refund points to the teammate (use base type for generic refund; table requires type)
        refund_transaction = KudosTransaction.create!(
          type: 'KudosTransaction',
          company_teammate: @redemption.company_teammate,
          organization: organization,
          points_to_spend_delta: @redemption.points_spent,
          reason: "Refund for cancelled redemption ##{@redemption.id}"
        )
        refund_transaction.apply_to_ledger!
      end

      flash[:notice] = "Redemption cancelled and #{@redemption.points_spent.to_i} points refunded."
    rescue KudosRedemption::InvalidStateTransition => e
      flash[:alert] = "Cannot cancel this redemption: #{e.message}"
    rescue => e
      flash[:alert] = "Error cancelling redemption: #{e.message}"
    end

    redirect_to organization_kudos_rewards_redemption_path(organization, @redemption)
  end

  private

  def set_redemption
    @redemption = organization.kudos_redemptions.find(params[:id])
  end

  def authorize_view!
    if @redemption.company_teammate == current_company_teammate
      authorize :kudos, :view_own_redemptions?
    else
      authorize :kudos, :view_all_redemptions?
    end
  end

  def authorize_status_management!
    authorize :kudos, :manage_redemption_status?
  end

  def redemption_params
    params.require(:redemption).permit(:reward_id, :notes)
  end
end
