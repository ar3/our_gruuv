module KudosHelper
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
    "#{points} points (#{kudos_dollar_value(points)})"
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
