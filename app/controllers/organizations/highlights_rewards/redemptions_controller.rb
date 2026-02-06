# Controller for managing reward redemptions
class Organizations::HighlightsRewards::RedemptionsController < Organizations::HighlightsRewards::BaseController
  before_action :set_redemption, only: [:show, :fulfill, :cancel]
  before_action :authorize_status_management!, only: [:fulfill, :cancel]

  # List redemptions - own or all (admin)
  def index
    if policy(:highlights).view_all_redemptions?
      # Admin view - show all redemptions
      authorize :highlights, :view_all_redemptions?
      redemptions_scope = organization.highlights_redemptions
        .includes(:company_teammate, :highlights_reward)
        .recent
      total_count = redemptions_scope.count
      @pagy = Pagy.new(count: total_count, page: params[:page] || 1, items: 25)
      @redemptions = redemptions_scope.limit(@pagy.items).offset(@pagy.offset)
      @view_mode = :admin
    else
      # User view - show own redemptions
      authorize :highlights, :view_own_redemptions?
      redemptions_scope = current_company_teammate.highlights_redemptions
        .includes(:highlights_reward)
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
    authorize :highlights, :redeem_reward?

    @reward = organization.highlights_rewards.active.find(params[:reward_id])
    @ledger = current_company_teammate.highlights_ledger
    @can_afford = @ledger.can_spend?(@reward.cost_in_points)
  end

  # Process redemption
  def create
    authorize :highlights, :redeem_reward?

    @reward = organization.highlights_rewards.active.find(redemption_params[:reward_id])

    result = Highlights::RedeemRewardService.call(
      company_teammate: current_company_teammate,
      reward: @reward,
      notes: redemption_params[:notes]
    )

    if result.ok?
      flash[:notice] = "Successfully redeemed #{@reward.name} for #{@reward.cost_in_points.to_i} points!"
      redirect_to organization_highlights_rewards_redemption_path(organization, result.value[:redemption])
    else
      flash[:alert] = result.error
      redirect_to organization_highlights_rewards_rewards_path(organization)
    end
  end

  # Admin: Mark redemption as fulfilled
  def fulfill
    external_ref = params[:external_reference]

    begin
      @redemption.mark_fulfilled!(external_ref: external_ref)
      flash[:notice] = "Redemption marked as fulfilled."
    rescue HighlightsRedemption::InvalidStateTransition => e
      flash[:alert] = "Cannot fulfill this redemption: #{e.message}"
    end

    redirect_to organization_highlights_rewards_redemption_path(organization, @redemption)
  end

  # Admin: Cancel redemption and refund points
  def cancel
    reason = params[:reason] || "Cancelled by admin"

    begin
      ApplicationRecord.transaction do
        @redemption.mark_cancelled!(reason: reason)

        # Refund points to the teammate
        refund_transaction = HighlightsTransaction.create!(
          type: 'HighlightsTransaction',
          company_teammate: @redemption.company_teammate,
          organization: organization,
          points_to_spend_delta: @redemption.points_spent,
          reason: "Refund for cancelled redemption ##{@redemption.id}"
        )
        refund_transaction.apply_to_ledger!
      end

      flash[:notice] = "Redemption cancelled and #{@redemption.points_spent.to_i} points refunded."
    rescue HighlightsRedemption::InvalidStateTransition => e
      flash[:alert] = "Cannot cancel this redemption: #{e.message}"
    rescue => e
      flash[:alert] = "Error cancelling redemption: #{e.message}"
    end

    redirect_to organization_highlights_rewards_redemption_path(organization, @redemption)
  end

  private

  def set_redemption
    @redemption = organization.highlights_redemptions.find(params[:id])
  end

  def authorize_view!
    if @redemption.company_teammate == current_company_teammate
      authorize :highlights, :view_own_redemptions?
    else
      authorize :highlights, :view_all_redemptions?
    end
  end

  def authorize_status_management!
    authorize :highlights, :manage_redemption_status?
  end

  def redemption_params
    params.require(:redemption).permit(:reward_id, :notes)
  end
end
