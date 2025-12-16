class UserPreference < ApplicationRecord
  belongs_to :person
  
  # Default preferences structure
  DEFAULT_PREFERENCES = {
    layout: 'vertical',
    vertical_nav_open: false,
    vertical_nav_locked: false
  }.freeze
  
  # Ensure preferences is always a hash with defaults
  before_validation :ensure_preferences_hash
  after_initialize :set_default_preferences, if: :new_record?
  
  # Get preference value with default fallback
  def preference(key)
    preferences[key.to_s] || DEFAULT_PREFERENCES[key.to_sym]
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
  
  # Find or create preferences for a person
  def self.for_person(person)
    find_or_create_by(person: person) do |pref|
      pref.preferences = DEFAULT_PREFERENCES.dup
    end
  end
  
  private
  
  def set_default_preferences
    self.preferences = DEFAULT_PREFERENCES.dup if preferences.nil? || preferences.empty?
  end
  
  def ensure_preferences_hash
    self.preferences = {} if preferences.nil?
    # Merge with defaults to ensure all keys exist
    if preferences.is_a?(Hash)
      self.preferences = DEFAULT_PREFERENCES.merge(preferences.stringify_keys)
    end
  end
end

