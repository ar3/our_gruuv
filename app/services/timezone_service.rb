class TimezoneService
  def self.valid_timezone?(timezone_name)
    return false if timezone_name.blank?
    
    # Check if it's a valid timezone using Rails' timezone functionality
    ActiveSupport::TimeZone[timezone_name].present?
  end
  
  def self.all_timezones
    ActiveSupport::TimeZone.all.map(&:name)
  end
  
  def self.us_timezones
    ActiveSupport::TimeZone.us_zones.map(&:name)
  end

  def self.detect_timezone_from_request(request)
    accept_language = request.headers['Accept-Language']
    if accept_language
      Rails.logger.debug "🔍 detect_timezone_from_request: Accept-Language: #{accept_language}"
      # Extract locale and try to map to timezone
      locale = accept_language.split(',').first&.strip
      Rails.logger.debug "🔍 detect_timezone_from_request: locale: #{locale}"
      timezone = TimezoneService.map_locale_to_timezone(locale)
      Rails.logger.debug "🔍 detect_timezone_from_request: timezone: #{timezone}"
      timezone = TimezoneService.all_timezones.find { |tz| tz == timezone }
      Rails.logger.debug "🔍 detect_timezone_from_request: final timezone: #{timezone}"
      return timezone if timezone
    end
    
    'Eastern Time (US & Canada)'
  end

  # Map common locales to timezones
  def self.map_locale_to_timezone(locale)
    return nil unless locale
    
    # Common locale to timezone mappings
    mappings = {
      'en-US' => 'Eastern Time (US & Canada)',
      'en-CA' => 'Eastern Time (US & Canada)',
      'en-GB' => 'London',
      'en-AU' => 'Sydney',
      'en-NZ' => 'Wellington',
      'fr-CA' => 'Eastern Time (US & Canada)',
      'fr-FR' => 'Paris',
      'de-DE' => 'Berlin',
      'es-ES' => 'Madrid',
      'es-MX' => 'Central Time (US & Canada)',
      'pt-BR' => 'Brasilia',
      'ja-JP' => 'Tokyo',
      'ko-KR' => 'Seoul',
      'zh-CN' => 'Beijing',
      'zh-TW' => 'Taipei'
    }
    
    mappings[locale] || mappings[locale.split('-').first]
  end
end 