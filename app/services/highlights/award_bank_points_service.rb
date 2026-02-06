# app/services/highlights/award_bank_points_service.rb
# Service for awarding points from the company bank to a teammate
class Highlights::AwardBankPointsService
  def self.call(...) = new(...).call

  def initialize(banker:, recipient:, points_to_give: 0, points_to_spend: 0, reason:)
    @banker = banker
    @recipient = recipient
    @points_to_give = normalize_points(points_to_give)
    @points_to_spend = normalize_points(points_to_spend)
    @reason = reason
    @organization = banker.organization
  end

  def call
    validate_permissions!
    validate_same_organization!

    ApplicationRecord.transaction do
      transaction = create_transaction!
      transaction.apply_to_ledger!
      Result.ok(transaction)
    end
  rescue ActiveRecord::RecordInvalid => e
    Result.err(e.record.errors.full_messages.join(', '))
  rescue ArgumentError => e
    Result.err(e.message)
  rescue => e
    Result.err("Failed to award points: #{e.message}")
  end

  private

  def validate_permissions!
    unless @banker.can_manage_highlights_rewards?
      raise ArgumentError, "Banker does not have permission to award points"
    end
  end

  def validate_same_organization!
    unless @banker.organization_id == @recipient.organization_id
      raise ArgumentError, "Banker and recipient must be in the same organization"
    end
  end

  def create_transaction!
    BankAwardTransaction.create!(
      company_teammate: @recipient,
      organization: @organization,
      company_teammate_banker: @banker,
      points_to_give_delta: @points_to_give,
      points_to_spend_delta: @points_to_spend,
      reason: @reason
    )
  end

  # Normalize points to 0.5 increments (round up)
  def normalize_points(value)
    return 0.0 if value.blank? || value.to_f <= 0

    raw = value.to_f
    # Round up to nearest 0.5
    (raw * 2).ceil / 2.0
  end
end
