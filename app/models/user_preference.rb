class UserPreference < ApplicationRecord
  belongs_to :person
  
  # Default preferences structure
  WEEKLY_DIGEST_TOGGLE_KEYS = %w[about_me_digest_enabled one_on_one_digest_enabled].freeze

  DEFAULT_PREFERENCES = {
    layout: 'vertical',
    vertical_nav_open: false,
    vertical_nav_locked: false,
    vertical_nav_mode: 'closed_unless_opened',
    digest_slack: 'off',
    digest_email: 'off',
    digest_sms: 'off',
    digest_weekly_day: nil,
    about_me_weekly_day: 'off',
    about_me_last_sent_week: nil,
    one_on_one_last_sent_week: nil,
    about_me_digest_enabled: 'off',
    one_on_one_digest_enabled: 'on'
  }.freeze
  
  # Ensure preferences is always a hash with defaults
  before_validation :ensure_preferences_hash
  after_initialize :set_default_preferences, if: :new_record?
  
  # Get preference value with default fallback
  def preference(key)
    preferences[key.to_s] || DEFAULT_PREFERENCES[key.to_sym]
  end

  def weekly_digest_enabled?(key)
    preference(key) == 'on'
  end
  
  # Set preference value
  def update_preference(key, value)
    self.preferences = preferences.merge(key.to_s => value)
    save
  end
  
  # Convenience methods for common preferences
  def layout
    preference(:layout)
  end
  
  def vertical_nav_open?
    preference(:vertical_nav_open)
  end
  
  def vertical_nav_locked?
    preference(:vertical_nav_locked)
  end

  def vertical_nav_mode
    preference(:vertical_nav_mode).to_s
  end

  # Digest preferences: stored value or 'off'. No automatic weekly default so scheduled digests
  # only go to people who have explicitly chosen daily/weekly (opt-in until we launch).
  def effective_digest_slack(teammate)
    normalized_digest_medium_value(preferences['digest_slack'])
  end

  def effective_digest_email
    normalized_digest_medium_value(preferences['digest_email'])
  end

  def effective_digest_sms(person_or_nil = nil)
    normalized_digest_medium_value(preferences['digest_sms'])
  end

  # Find or create preferences for a person
  def self.for_person(person)
    find_or_create_by(person: person) do |pref|
      pref.preferences = default_preferences_without_weekly_digest_toggles
    end
  end

  def self.default_preferences_without_weekly_digest_toggles
    DEFAULT_PREFERENCES.stringify_keys.except(*WEEKLY_DIGEST_TOGGLE_KEYS)
  end
  
  private

  def normalized_digest_medium_value(value)
    raw = value.to_s
    return 'on' if raw == 'on'
    return 'on' if %w[daily weekly].include?(raw) # Backward compatibility for existing records

    'off'
  end
  
  def set_default_preferences
    if preferences.nil? || preferences.empty?
      self.preferences = self.class.default_preferences_without_weekly_digest_toggles
    end
  end
  
  def ensure_preferences_hash
    self.preferences = {} if preferences.nil?
    # Merge with defaults to ensure all keys exist (weekly digest toggles are opt-in via stored keys)
    if preferences.is_a?(Hash)
      base_defaults = DEFAULT_PREFERENCES.stringify_keys.except(*WEEKLY_DIGEST_TOGGLE_KEYS)
      self.preferences = base_defaults.merge(preferences.stringify_keys)
    end
  end
end
