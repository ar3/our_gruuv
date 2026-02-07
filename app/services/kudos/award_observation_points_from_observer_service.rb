# Service for awarding kudos points from observer's balance to observees (nudge flow).
# Observer chooses the total amount; it is split equally among observees (excluding observer).
class Kudos::AwardObservationPointsFromObserverService
  def self.call(...) = new(...).call

  def initialize(observation:, points_total:)
    @observation = observation
    @points_total = points_total.to_f
    @organization = observation.company
    @observer = observation.observer
    @observees = eligible_observees
  end

  def call
    return Result.err("Observation has no observees to award") if @observees.empty?
    return Result.err("Observation is not published") unless @observation.published?
    return Result.err("Points already processed for this observation") if already_processed?

    observer_teammate = find_observer_teammate
    return Result.err("Observer is not a teammate in this organization") unless observer_teammate

    observer_ledger = observer_teammate.kudos_ledger
    return Result.err("You don't have enough points to give") unless observer_ledger.can_give?(@points_total)

    transactions = []

    ApplicationRecord.transaction do
      # 1. Deduct from observer's points to give
      observer_debit = ObserverGiveTransaction.create!(
        company_teammate: observer_teammate,
        organization: @organization,
        observation: @observation,
        points_to_give_delta: -@points_total,
        points_to_spend_delta: 0
      )
      observer_debit.apply_to_ledger!
      transactions << observer_debit

      # 2. Credit each observee (split equally)
      points_per_observee = calculate_points_per_observee(@points_total)
      @observees.each do |observee|
        exchange = PointsExchangeTransaction.create!(
          company_teammate: observee.company_teammate,
          organization: @organization,
          observation: @observation,
          points_to_give_delta: 0,
          points_to_spend_delta: points_per_observee
        )
        exchange.apply_to_ledger!
        transactions << exchange
      end

      # 3. Optional kickback to observer (same config as ProcessObservationPointsService)
      feedback_type = @observation.has_negative_ratings? ? :constructive : :recognition
      config = points_config(feedback_type)
      kickback = award_kickback_to_observer(observer_teammate, config, feedback_type)
      kickback.apply_to_ledger!
      transactions << kickback
    end

    Result.ok(transactions)
  rescue ActiveRecord::RecordInvalid => e
    Result.err(e.record.errors.full_messages.join(', '))
  rescue KudosPointsLedger::InsufficientBalance => e
    Result.err("You don't have enough points to give")
  rescue => e
    Rails.logger.error "Failed to award observation points: #{e.message}"
    Result.err("Failed to award points: #{e.message}")
  end

  private

  def eligible_observees
    @observation.observees.includes(:company_teammate).reject do |o|
      o.company_teammate.person_id == @observation.observer_id
    end
  end

  def already_processed?
    PointsExchangeTransaction.exists?(observation: @observation)
  end

  def find_observer_teammate
    CompanyTeammate.find_by(person: @observer, organization: @organization)
  end

  def calculate_points_per_observee(total_points)
    count = @observees.count
    return normalize_points(total_points) if count == 1

    per_person = total_points.to_f / count
    normalize_points(per_person)
  end

  def normalize_points(value)
    return 0.0 if value.blank? || value.to_f <= 0

    raw = value.to_f
    (raw * 2).ceil / 2.0
  end

  DEFAULT_CONFIGS = {
    recognition: {
      observer_kickback_give: 0.5,
      observer_kickback_spend: 0.0
    },
    constructive: {
      observer_kickback_give: 2.0,
      observer_kickback_spend: 2.0
    }
  }.freeze

  def points_config(feedback_type)
    org_config = @organization.kudos_celebratory_points_for("observation_#{feedback_type}")
    if org_config.present?
      {
        observer_kickback_give: org_config['observer_kickback_give']&.to_f || DEFAULT_CONFIGS[feedback_type][:observer_kickback_give],
        observer_kickback_spend: org_config['observer_kickback_spend']&.to_f || DEFAULT_CONFIGS[feedback_type][:observer_kickback_spend]
      }
    else
      DEFAULT_CONFIGS[feedback_type]
    end
  end

  def award_kickback_to_observer(observer_teammate, config, feedback_type)
    give_points = normalize_points(config[:observer_kickback_give])
    spend_points = normalize_points(config[:observer_kickback_spend])

    if feedback_type == :recognition
      give_points = normalize_points(@points_total * config[:observer_kickback_give])
    end

    KickbackRewardTransaction.create!(
      company_teammate: observer_teammate,
      organization: @organization,
      observation: @observation,
      points_to_give_delta: give_points,
      points_to_spend_delta: spend_points
    )
  end
end
