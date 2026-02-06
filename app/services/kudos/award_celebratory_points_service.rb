# app/services/kudos/award_celebratory_points_service.rb
# Service for awarding celebratory points when an observable moment occurs
# Points come from the "company bank" and are awarded to the associated teammate
class Kudos::AwardCelebratoryPointsService
  def self.call(...) = new(...).call

  # Default point configurations for each moment type
  # Organizations can override these in their kudos_celebratory_config
  DEFAULT_CONFIGS = {
    'new_hire' => { 'points_to_give' => 50.0, 'points_to_spend' => 25.0 },
    'seat_change' => { 'points_to_give' => 25.0, 'points_to_spend' => 10.0 },
    'ability_milestone' => { 'points_to_give' => 20.0, 'points_to_spend' => 10.0 },
    'check_in_completed' => { 'points_to_give' => 10.0, 'points_to_spend' => 5.0 },
    'goal_check_in' => { 'points_to_give' => 5.0, 'points_to_spend' => 2.5 }
  }.freeze

  def initialize(observable_moment:)
    @observable_moment = observable_moment
    @organization = observable_moment.company
  end

  def call
    return Result.err("No associated teammate found for this moment") unless recipient.present?
    return Result.err("Celebratory points already awarded for this moment") if already_awarded?

    config = points_config
    return Result.err("No point configuration for moment type: #{moment_type}") if config.blank?

    points_to_give = normalize_points(config['points_to_give'])
    points_to_spend = normalize_points(config['points_to_spend'])

    return Result.err("No points configured for moment type: #{moment_type}") if points_to_give <= 0 && points_to_spend <= 0

    ApplicationRecord.transaction do
      transaction = create_transaction!(points_to_give, points_to_spend)
      transaction.apply_to_ledger!
      Result.ok(transaction)
    end
  rescue ActiveRecord::RecordInvalid => e
    Result.err(e.record.errors.full_messages.join(', '))
  rescue => e
    Rails.logger.error "Failed to award celebratory points: #{e.message}"
    Result.err("Failed to award celebratory points: #{e.message}")
  end

  private

  def recipient
    @recipient ||= @observable_moment.associated_teammate
  end

  def moment_type
    @observable_moment.moment_type
  end

  def already_awarded?
    CelebratoryAwardTransaction.exists?(
      observable_moment: @observable_moment,
      company_teammate: recipient
    )
  end

  def points_config
    # Organization-specific config takes precedence over defaults
    org_config = @organization.kudos_celebratory_points_for(moment_type)
    return org_config if org_config.present? && (org_config['points_to_give'].to_f > 0 || org_config['points_to_spend'].to_f > 0)

    # Fall back to defaults
    DEFAULT_CONFIGS[moment_type]
  end

  def create_transaction!(points_to_give, points_to_spend)
    CelebratoryAwardTransaction.create!(
      company_teammate: recipient,
      organization: @organization,
      observable_moment: @observable_moment,
      points_to_give_delta: points_to_give,
      points_to_spend_delta: points_to_spend
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
