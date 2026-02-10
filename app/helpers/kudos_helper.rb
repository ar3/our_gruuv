module KudosHelper
  DEFAULT_PEER_TO_PEER_LIMITS = {
    'solid_ratings_min' => 5,
    'solid_ratings_max' => 25,
    'exceptional_ratings_min' => 30,
    'exceptional_ratings_max' => 50
  }.freeze

  # Returns { min:, max:, point_options: } for use in observer award-by-rating dropdowns.
  # rating_kind is :solid (agree) or :exceptional (strongly_agree).
  def peer_to_peer_point_options_for(organization, rating_kind)
    limits = organization.kudos_points_economy_config&.dig('peer_to_peer_rating_limits') || {}
    key_min = "#{rating_kind}_ratings_min"
    key_max = "#{rating_kind}_ratings_max"
    min = (limits[key_min] || DEFAULT_PEER_TO_PEER_LIMITS[key_min]).to_i
    max = (limits[key_max] || DEFAULT_PEER_TO_PEER_LIMITS[key_max]).to_i
    min, max = max, min if min > max
    diff = max - min
    point_options = if diff <= 15
      (min..max).to_a
    else
      opts = min.step(max, 5).to_a
      opts << max if opts.last != max
      opts
    end
    { min: min, max: max, point_options: point_options }
  end

  # Returns { points_to_give_options:, points_to_spend_options:, max_points_to_give:, max_points_to_spend: } for
  # celebratory org-bank award dropdowns. Uses organization config or Kudos::AwardCelebratoryPointsService defaults.
  def celebratory_bank_point_options_for(organization, moment_type)
    config = organization.kudos_celebratory_points_for(moment_type)
    if config.blank? || (config['points_to_give'].to_f <= 0 && config['points_to_spend'].to_f <= 0)
      config = Kudos::AwardCelebratoryPointsService::DEFAULT_CONFIGS[moment_type.to_s] || {}
    end
    max_give = config['points_to_give'].to_f
    max_spend = config['points_to_spend'].to_f
    give_options = build_celebratory_bank_point_options(max_give)
    spend_options = build_celebratory_bank_point_options(max_spend)
    {
      points_to_give_options: give_options,
      points_to_spend_options: spend_options,
      max_points_to_give: max_give,
      max_points_to_spend: max_spend
    }
  end

  # Increment rules for celebratory bank dropdowns: max < 16 => 1, 16..40 => 5, 41..150 => 10, > 150 => 25
  def celebratory_bank_step_for(max_value)
    return 1 if max_value < 16
    return 5 if max_value <= 40
    return 10 if max_value <= 150
    25
  end

  def build_celebratory_bank_point_options(max_value)
    return [] if max_value.blank? || max_value <= 0
    step = celebratory_bank_step_for(max_value)
    options = 0.step(max_value.to_f, step).to_a
    options << max_value if options.last != max_value
    options.map(&:to_i)
  end

  def kudos_transaction_description(transaction)
    case transaction
    when BankAwardTransaction
      banker_name = transaction.company_teammate_banker&.person&.display_name || "Admin"
      "Bank award from #{banker_name}: #{truncate(transaction.reason, length: 50)}"
    when CelebratoryAwardTransaction
      "Celebration: #{truncate(transaction.moment_display_name, length: 50)}"
    when PointsExchangeTransaction
      if transaction.observation
        "Observation: #{truncate(transaction.observation.story, length: 40)}"
      else
        "Point exchange"
      end
    when KickbackRewardTransaction
      "Kickback for giving feedback"
    when RedemptionTransaction
      reward_name = transaction.kudos_redemption&.kudos_reward&.name || "reward"
      "Redeemed: #{reward_name}"
    else
      "Transaction"
    end
  end

  def kudos_format_delta(delta)
    return "-" if delta.nil? || delta == 0

    prefix = delta > 0 ? "+" : ""
    "#{prefix}#{delta}"
  end

  def kudos_delta_class(delta)
    return "" if delta.nil? || delta == 0
    delta > 0 ? "text-success" : "text-danger"
  end

  def kudos_dollar_value(points)
    number_to_currency(points / 10.0)
  end

  def kudos_points_display(points)
    formatted = number_with_precision(points.to_f, strip_insignificant_zeros: true)
    "#{formatted} #{company_label_plural('kudos_point', 'Kudos Point')}"
  end

  def reward_type_badge_class(reward_type)
    case reward_type
    when 'gift_card' then 'bg-primary'
    when 'merchandise' then 'bg-info'
    when 'experience' then 'bg-success'
    when 'donation' then 'bg-warning text-dark'
    when 'custom' then 'bg-secondary'
    else 'bg-secondary'
    end
  end

  def redemption_status_badge_class(status)
    case status
    when 'pending' then 'bg-warning text-dark'
    when 'processing' then 'bg-info'
    when 'fulfilled' then 'bg-success'
    when 'failed' then 'bg-danger'
    when 'cancelled' then 'bg-secondary'
    else 'bg-secondary'
    end
  end
end
