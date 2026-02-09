class Organizations::KudosRewards::BankAwardsController < Organizations::KudosRewards::BaseController
  before_action :authorize_view_dashboard!, only: [:index]
  before_action :authorize_banker!, only: [:new, :create]
  before_action :set_recipient, only: [:new, :create]

  def index
    @recent_awards = BankAwardTransaction
      .where(organization: organization)
      .includes(:company_teammate, :company_teammate_banker)
      .recent
      .limit(50)

    @total_points_to_give = KudosPointsLedger.where(organization: organization).sum(:points_to_give)
    @total_points_to_redeem = KudosPointsLedger.where(organization: organization).sum(:points_to_spend)
  end

  def new
    @teammates = organization.teammates
      .joins(:person)
      .where.not(id: current_company_teammate.id)
      .order('people.first_name, people.last_name')
  end

  def create
    result = Kudos::AwardBankPointsService.call(
      banker: current_company_teammate,
      recipient: @recipient,
      points_to_give: award_params[:points_to_give],
      points_to_spend: award_params[:points_to_spend],
      reason: award_params[:reason]
    )

    if result.ok?
      flash[:notice] = "Successfully awarded #{result.value.award_summary} to #{@recipient.person.display_name}"
      redirect_to organization_kudos_rewards_bank_awards_path(organization)
    else
      flash.now[:alert] = result.error
      @teammates = organization.teammates
        .joins(:person)
        .where.not(id: current_company_teammate.id)
        .order('people.first_name, people.last_name')
      render :new, status: :unprocessable_entity
    end
  end

  private

  def authorize_view_dashboard!
    authorize :kudos, :view_dashboard?
  end

  def authorize_banker!
    authorize :kudos, :award_bank_points?
  end

  def set_recipient
    recipient_id = params[:recipient_id].presence || params.dig(:bank_award, :recipient_id).presence
    return unless recipient_id.present?

    @recipient = organization.teammates.find(recipient_id)
  rescue ActiveRecord::RecordNotFound
    flash[:alert] = "Recipient not found"
    redirect_to new_organization_kudos_rewards_bank_award_path(organization)
  end

  def award_params
    params.require(:bank_award).permit(:recipient_id, :points_to_give, :points_to_spend, :reason)
  end
end
