class TimezoneService
  DEFAULT_TIMEZONE = 'Eastern Time (US & Canada)'

  def self.valid_timezone?(timezone_name)
    return false if timezone_name.blank?
    ActiveSupport::TimeZone[timezone_name].present?
  end

  def self.all_timezones
    ActiveSupport::TimeZone.all.map(&:name)
  end

  def self.us_timezones
    ActiveSupport::TimeZone.us_zones.map(&:name)
  end

  def self.ensure_valid_timezone(timezone_name)
    return DEFAULT_TIMEZONE if timezone_name.blank?
    return timezone_name if valid_timezone?(timezone_name)
    DEFAULT_TIMEZONE
  end

  def self.map_locale_to_timezone(locale)
    return nil if locale.blank?
    
    case locale.downcase
    when 'en-us', 'en'
      'Eastern Time (US & Canada)'
    when 'en-ca'
      'Eastern Time (US & Canada)'
    when 'en-gb'
      'London'
    when 'fr-fr', 'fr'
      'Paris'
    when 'de-de', 'de'
      'Berlin'
    when 'es-es', 'es', 'es-mx'
      'Central Time (US & Canada)'
    when 'it-it', 'it'
      'Rome'
    when 'ja-jp', 'ja'
      'Tokyo'
    when 'ko-kr', 'ko'
      'Seoul'
    when 'zh-cn', 'zh'
      'Beijing'
    else
      nil
    end
  end

  def self.detect_from_request(request)
    return DEFAULT_TIMEZONE unless request&.headers&.key?('Accept-Language')
    
    accept_language = request.headers['Accept-Language']
    return DEFAULT_TIMEZONE if accept_language.blank?
    
    # Parse the Accept-Language header and extract the primary locale
    locale = accept_language.split(',').first&.split(';')&.first&.strip
    return DEFAULT_TIMEZONE if locale.blank?
    
    # Use the extracted method to map locale to timezone
    mapped_timezone = map_locale_to_timezone(locale)
    mapped_timezone || DEFAULT_TIMEZONE
  end

  def self.valid_timezones
    all_timezones
  end

  def self.timezone_options
    all_timezones.map { |tz| [tz, tz] }
  end

  def self.format_time(time, timezone_name = DEFAULT_TIMEZONE)
    timezone = ensure_valid_timezone(timezone_name)
    time.in_time_zone(timezone).strftime('%B %d, %Y at %I:%M %p %Z')
  end
end 