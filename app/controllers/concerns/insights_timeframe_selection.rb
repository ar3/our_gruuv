# frozen_string_literal: true

# Shared timeframe parsing for Insights pages and Value / Billing (Last 90 days, Year, All-Time, Custom).
module InsightsTimeframeSelection
  extend ActiveSupport::Concern

  private

  def parse_timeframe(param)
    case param.to_s
    when 'year' then :year
    when 'all_time' then :all_time
    when 'custom' then :custom
    else :'90_days'
    end
  end

  def date_range_for(timeframe)
    case timeframe
    when :'90_days'
      90.days.ago..Time.current
    when :year
      1.year.ago..Time.current
    when :all_time, :custom
      nil
    else
      90.days.ago..Time.current
    end
  end

  # Returns [range, custom_from_str, custom_to_str]. For preset timeframes, custom dates are nil.
  # For :custom, range is from params (or defaults); from/to strings feed the date inputs and Custom link.
  def insights_date_range_and_custom_fields
    case @timeframe
    when :custom
      insights_custom_date_range
    else
      [date_range_for(@timeframe), nil, nil]
    end
  end

  def insights_custom_date_range
    default_from = 90.days.ago.to_date
    default_to = Time.zone.today
    from_s = params[:from].presence
    to_s = params[:to].presence

    unless from_s && to_s
      range = default_from.beginning_of_day..default_to.end_of_day
      return [range, default_from.iso8601, default_to.iso8601]
    end

    begin
      from_d = Date.iso8601(from_s)
      to_d = Date.iso8601(to_s)
    rescue ArgumentError
      flash.now[:alert] = 'Enter valid From and To dates (YYYY-MM-DD).'
      range = default_from.beginning_of_day..default_to.end_of_day
      return [range, from_s, to_s]
    end

    if from_d > to_d
      flash.now[:alert] = 'From date must be on or before To date.'
      range = default_from.beginning_of_day..default_to.end_of_day
      return [range, from_s, to_s]
    end

    range = from_d.beginning_of_day..to_d.end_of_day
    [range, from_s, to_s]
  end

  def insights_chart_title_period(timeframe, range, chart_range)
    case timeframe
    when :'90_days' then 'Last 90 Days'
    when :year then 'Last Year'
    when :all_time then 'Last 52 Weeks'
    when :custom
      r = range
      r ||= chart_range
      return 'Custom range' unless r
      "#{r.begin.in_time_zone.strftime('%b %-d, %Y')} – #{r.end.in_time_zone.strftime('%b %-d, %Y')}"
    else
      'Last 90 Days'
    end
  end
end
