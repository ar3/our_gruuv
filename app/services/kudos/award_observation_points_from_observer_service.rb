# Service for awarding kudos points from observer's balance to observees (nudge flow).
# Accepts per-rating rewards; total is split equally among observees (excluding observer).
# Allows overdraft when awarding exactly one rating and total <= that rating's minimum.
class Kudos::AwardObservationPointsFromObserverService
  DEFAULT_PEER_TO_PEER_LIMITS = {
    'solid_ratings_min' => 5,
    'solid_ratings_max' => 25,
    'exceptional_ratings_min' => 30,
    'exceptional_ratings_max' => 50
  }.freeze

  def self.call(...) = new(...).call

  def initialize(observation:, rating_rewards:)
    @observation = observation
    @organization = observation.company
    @observer = observation.observer
    @observees = eligible_observees
    @rating_rewards = resolve_rating_rewards(rating_rewards)
    @points_total = @rating_rewards.sum { |r| r[:points].to_f }
  end

  def call
    return Result.err("Observation has no observees to award") if @observees.empty?
    return Result.err("Observation is not published") unless @observation.published?
    return Result.err("Points already processed for this observation") if already_processed?
    return Result.err("Please select at least one rating and enter points.") if @rating_rewards.empty? || @points_total <= 0

    observer_teammate = find_observer_teammate
    return Result.err("Observer is not a teammate in this organization") unless observer_teammate

    observer_ledger = observer_teammate.kudos_ledger
    balance = observer_ledger.points_to_give

    points_per_observee = calculate_points_per_observee(@points_total)
    total_to_deduct = @observees.count > 1 ? (points_per_observee * @observees.count) : points_per_observee

    min_for_single_rating = nil
    min_for_single_rating = min_for_rating(@rating_rewards.first[:observation_rating_id]) if @rating_rewards.size == 1

    deduct_int = total_to_deduct.to_i
    min_int = min_for_single_rating&.to_i
    allowed = balance >= total_to_deduct
    if !allowed && @rating_rewards.size == 1 && min_int
      # Allow overdraft when awarding at or below the minimum for that single rating
      allowed = deduct_int <= min_int || (balance.to_i + min_int) >= deduct_int
    end

    unless allowed
      return Result.err(
        "You don't have enough points to spend to give this reward; the #{@organization.name} bank will allow overdraft on the minimum points of one rating."
      )
    end

    use_overdraft_path = balance < total_to_deduct

    transactions = []

    ApplicationRecord.transaction do
      observer_debit = ObserverGiveTransaction.create!(
        company_teammate: observer_teammate,
        organization: @organization,
        observation: @observation,
        points_to_give_delta: -total_to_deduct,
        points_to_spend_delta: 0
      )
      if use_overdraft_path
        observer_ledger.apply_debit_from_give(total_to_deduct)
      else
        observer_debit.apply_to_ledger!
      end
      transactions << observer_debit
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

  def resolve_rating_rewards(rating_rewards)
    return [] if rating_rewards.blank?
    ids = rating_rewards.map { |r| r[:observation_rating_id] || r['observation_rating_id'] }.compact.uniq
    return [] if ids.empty?
    valid_ids = @observation.observation_ratings.positive.where(id: ids).pluck(:id).to_set
    rating_rewards.filter_map do |r|
      id = (r[:observation_rating_id] || r['observation_rating_id']).to_i
      next unless valid_ids.include?(id)
      pts = (r[:points] || r['points']).to_f
      next if pts <= 0
      { observation_rating_id: id, points: normalize_points(pts) }
    end
  end

  def min_for_rating(observation_rating_id)
    rating = @observation.observation_ratings.positive.find_by(id: observation_rating_id)
    return nil unless rating
    limits = @organization.kudos_points_economy_config&.dig('peer_to_peer_rating_limits') || {}
    key = rating.strongly_agree? ? 'exceptional_ratings_min' : 'solid_ratings_min'
    (limits[key] || DEFAULT_PEER_TO_PEER_LIMITS[key]).to_i
  end

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

    # When multiple recipients, round up each share to nearest whole number
    per_person = total_points.to_f / count
    per_person.ceil.to_i
  end

  def normalize_points(value)
    return 0 if value.blank? || value.to_f <= 0

    value.to_f.round
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
