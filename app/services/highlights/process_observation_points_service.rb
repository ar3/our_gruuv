# app/services/highlights/process_observation_points_service.rb
# Service for processing highlights points when an observation is published
# Awards points to observees and kickback rewards to observers
class Highlights::ProcessObservationPointsService
  def self.call(...) = new(...).call

  # Default point configurations
  # Recognition: Observer gives points from their balance, gets kickback
  # Constructive: Points come from company bank, observer gets larger kickback
  DEFAULT_CONFIGS = {
    recognition: {
      points_per_observee: 10.0,       # Points to spend given to each observee
      observer_kickback_give: 0.5,     # Points to give earned by observer per point given
      observer_kickback_spend: 0.0     # Points to spend earned by observer
    },
    constructive: {
      points_per_observee: 5.0,        # Points to spend given to each observee (from company bank)
      observer_kickback_give: 2.0,     # Points to give earned by observer
      observer_kickback_spend: 2.0     # Points to spend earned by observer
    }
  }.freeze

  def initialize(observation:)
    @observation = observation
    @organization = observation.company
    @observer = observation.observer
    @observees = observation.observees.includes(:company_teammate)
  end

  def call
    return Result.err("Observation has no observees") if @observees.empty?
    return Result.err("Observation is not published") unless @observation.published?
    return Result.err("Points already processed for this observation") if already_processed?

    observer_teammate = find_observer_teammate
    return Result.err("Observer is not a teammate in this organization") unless observer_teammate

    feedback_type = determine_feedback_type
    config = points_config(feedback_type)
    
    transactions = []

    ApplicationRecord.transaction do
      # Award points to each observee
      points_per_person = calculate_points_per_observee(config[:points_per_observee])
      
      @observees.each do |observee|
        transaction = award_points_to_observee(
          observee.company_teammate,
          points_per_person,
          feedback_type
        )
        transaction.apply_to_ledger!
        transactions << transaction
      end

      # Award kickback to observer
      kickback = award_kickback_to_observer(
        observer_teammate,
        config,
        feedback_type
      )
      kickback.apply_to_ledger!
      transactions << kickback
    end

    Result.ok(transactions)
  rescue ActiveRecord::RecordInvalid => e
    Result.err(e.record.errors.full_messages.join(', '))
  rescue HighlightsPointsLedger::InsufficientBalance => e
    Result.err("Observer doesn't have enough points to give: #{e.message}")
  rescue => e
    Rails.logger.error "Failed to process observation points: #{e.message}"
    Result.err("Failed to process observation points: #{e.message}")
  end

  private

  def already_processed?
    PointsExchangeTransaction.exists?(observation: @observation) ||
      KickbackRewardTransaction.exists?(observation: @observation)
  end

  def find_observer_teammate
    CompanyTeammate.find_by(person: @observer, organization: @organization)
  end

  def determine_feedback_type
    @observation.has_negative_ratings? ? :constructive : :recognition
  end

  def points_config(feedback_type)
    # Organization can override defaults
    org_config = @organization.highlights_celebratory_points_for("observation_#{feedback_type}")
    
    if org_config.present?
      {
        points_per_observee: org_config['points_per_observee']&.to_f || DEFAULT_CONFIGS[feedback_type][:points_per_observee],
        observer_kickback_give: org_config['observer_kickback_give']&.to_f || DEFAULT_CONFIGS[feedback_type][:observer_kickback_give],
        observer_kickback_spend: org_config['observer_kickback_spend']&.to_f || DEFAULT_CONFIGS[feedback_type][:observer_kickback_spend]
      }
    else
      DEFAULT_CONFIGS[feedback_type]
    end
  end

  # Split points among observees, round up to nearest 0.5
  def calculate_points_per_observee(total_points)
    count = @observees.count
    return normalize_points(total_points) if count == 1

    per_person = total_points.to_f / count
    normalize_points(per_person)
  end

  def award_points_to_observee(recipient, points, feedback_type)
    PointsExchangeTransaction.create!(
      company_teammate: recipient,
      organization: @organization,
      observation: @observation,
      points_to_give_delta: 0,
      points_to_spend_delta: points
    )
  end

  def award_kickback_to_observer(observer_teammate, config, feedback_type)
    give_points = normalize_points(config[:observer_kickback_give])
    spend_points = normalize_points(config[:observer_kickback_spend])

    # For recognition, scale kickback by total points given
    if feedback_type == :recognition
      total_points_given = @observees.count * calculate_points_per_observee(config[:points_per_observee])
      give_points = normalize_points(total_points_given * config[:observer_kickback_give])
    end

    KickbackRewardTransaction.create!(
      company_teammate: observer_teammate,
      organization: @organization,
      observation: @observation,
      points_to_give_delta: give_points,
      points_to_spend_delta: spend_points
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
