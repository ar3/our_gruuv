# Service for redeeming highlights points for a reward
# Creates redemption record and deducts points from ledger
class Highlights::RedeemRewardService
  def self.call(...) = new(...).call

  def initialize(company_teammate:, reward:, notes: nil)
    @company_teammate = company_teammate
    @reward = reward
    @organization = reward.organization
    @notes = notes
  end

  def call
    return Result.err("Reward is not available") unless reward_available?
    return Result.err("Teammate is not in the same organization as the reward") unless teammate_in_organization?
    return Result.err("Insufficient points to redeem this reward") unless can_afford?

    redemption = nil
    transaction = nil

    ApplicationRecord.transaction do
      redemption = create_redemption
      transaction = create_transaction(redemption)
      transaction.apply_to_ledger!
    end

    Result.ok({ redemption: redemption, transaction: transaction })
  rescue ActiveRecord::RecordInvalid => e
    Result.err(e.record.errors.full_messages.join(', '))
  rescue HighlightsPointsLedger::InsufficientBalance => e
    Result.err("Insufficient points: #{e.message}")
  rescue => e
    Rails.logger.error "Failed to redeem reward: #{e.message}"
    Result.err("Failed to redeem reward: #{e.message}")
  end

  private

  attr_reader :company_teammate, :reward, :organization, :notes

  def reward_available?
    reward.available?
  end

  def teammate_in_organization?
    company_teammate.organization_id == organization.id
  end

  def can_afford?
    ledger.can_spend?(reward.cost_in_points)
  end

  def ledger
    @ledger ||= company_teammate.highlights_ledger
  end

  def create_redemption
    HighlightsRedemption.create!(
      company_teammate: company_teammate,
      organization: organization,
      highlights_reward: reward,
      points_spent: reward.cost_in_points,
      status: 'pending',
      notes: notes
    )
  end

  def create_transaction(redemption)
    RedemptionTransaction.create!(
      company_teammate: company_teammate,
      organization: organization,
      highlights_redemption: redemption,
      points_to_give_delta: 0,
      points_to_spend_delta: -reward.cost_in_points,
      reason: "Redeemed #{reward.name}"
    )
  end
end
