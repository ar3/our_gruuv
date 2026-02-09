# frozen_string_literal: true

class Organizations::KudosRewards::LeaderboardController < Organizations::KudosRewards::BaseController
  def show
    authorize :kudos, :view_dashboard?

    @timeframe = parse_timeframe(params[:timeframe])
    range = date_range_for(@timeframe)

    @top_gifters = top_gifters(range)
    @top_recipients = top_recipients(range)
  end

  private

  def parse_timeframe(param)
    case param.to_s
    when 'year' then :year
    when 'all_time' then :all_time
    else :'90_days'
    end
  end

  def date_range_for(timeframe)
    case timeframe
    when :'90_days'
      90.days.ago..Time.current
    when :year
      1.year.ago..Time.current
    when :all_time
      nil
    else
      90.days.ago..Time.current
    end
  end

  def top_gifters(range)
    scope = ObserverGiveTransaction
      .where(organization: organization)
      .where(company_teammate_id: organization.teammates.select(:id))

    scope = scope.where(created_at: range) if range

    scope
      .group(:company_teammate_id)
      .select('company_teammate_id, SUM(ABS(points_to_give_delta)) AS total_given, COUNT(*) AS transaction_count')
      .order('total_given DESC')
      .limit(10)
      .includes(company_teammate: :person)
      .map do |row|
        {
          company_teammate: row.company_teammate,
          total_given: row.total_given.to_f,
          transaction_count: row.transaction_count.to_i,
          from_teammates_count: row.transaction_count.to_i,
          from_bank_count: 0
        }
      end
  end

  def top_recipients(range)
    # Only count points that went into the "to redeem" bucket (points_to_spend_delta)
    scope = KudosTransaction
      .where(organization: organization)
      .where(company_teammate_id: organization.teammates.select(:id))
      .where('points_to_spend_delta > 0')

    scope = scope.where(created_at: range) if range

    top_rows = scope
      .group(:company_teammate_id)
      .select(
        "company_teammate_id, " \
        "SUM(GREATEST(0, COALESCE(points_to_spend_delta, 0))) AS total_received"
      )
      .order('total_received DESC')
      .limit(10)
      .includes(company_teammate: :person)
      .to_a

    return [] if top_rows.empty?

    recipient_ids = top_rows.map(&:company_teammate_id)
    tx_scope = KudosTransaction
      .where(organization: organization, company_teammate_id: recipient_ids)
      .where('points_to_spend_delta > 0')
    tx_scope = tx_scope.where(created_at: range) if range

    transaction_counts = tx_scope.group(:company_teammate_id).count
    from_teammates_counts = PointsExchangeTransaction
      .joins(:observation)
      .where(organization: organization, company_teammate_id: recipient_ids)
      .where('points_to_spend_delta > 0')
      .where(observations: { observable_moment_id: nil })
    from_teammates_counts = from_teammates_counts.where(created_at: range) if range
    from_teammates_counts = from_teammates_counts.group(:company_teammate_id).count

    # "From the bank" = manual bank awards + celebratory only (not kickbacks), with to-redeem points
    bank_award_counts = BankAwardTransaction
      .where(organization: organization, company_teammate_id: recipient_ids)
      .where('points_to_spend_delta > 0')
    bank_award_counts = bank_award_counts.where(created_at: range) if range
    bank_award_counts = bank_award_counts.group(:company_teammate_id).count
    celebratory_counts = CelebratoryAwardTransaction
      .where(organization: organization, company_teammate_id: recipient_ids)
      .where('points_to_spend_delta > 0')
    celebratory_counts = celebratory_counts.where(created_at: range) if range
    celebratory_counts = celebratory_counts.group(:company_teammate_id).count
    from_bank_counts = recipient_ids.to_h { |id| [id, (bank_award_counts[id] || 0) + (celebratory_counts[id] || 0)] }

    from_bank_automation_counts = KickbackRewardTransaction
      .where(organization: organization, company_teammate_id: recipient_ids)
      .where('points_to_spend_delta > 0')
    from_bank_automation_counts = from_bank_automation_counts.where(created_at: range) if range
    from_bank_automation_counts = from_bank_automation_counts.group(:company_teammate_id).count

    top_rows.map do |row|
      tid = row.company_teammate_id
      total_tx = transaction_counts[tid] || 0
      from_teammates = from_teammates_counts[tid] || 0
      from_bank = from_bank_counts[tid] || 0
      from_bank_automation = from_bank_automation_counts[tid] || 0
      {
        company_teammate: row.company_teammate,
        total_received: row.total_received.to_f,
        transaction_count: total_tx,
        from_teammates_count: from_teammates,
        from_bank_count: from_bank,
        from_bank_automation_count: from_bank_automation
      }
    end
  end
end
