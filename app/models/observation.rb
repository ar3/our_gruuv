class Observation < ApplicationRecord
  include Notifiable
  include PgSearch::Model
  has_paper_trail
  
  belongs_to :observer, class_name: 'Person'
  belongs_to :company, class_name: 'Organization'
  has_many :observees, dependent: :destroy
  has_many :observed_teammates, through: :observees, source: :teammate
  has_many :observation_ratings, dependent: :destroy
  has_many :abilities, through: :observation_ratings, source: :rateable, source_type: 'Ability'
  has_many :assignments, through: :observation_ratings, source: :rateable, source_type: 'Assignment'
  has_many :aspirations, through: :observation_ratings, source: :rateable, source_type: 'Aspiration'
  has_many :notifications, as: :notifiable, dependent: :destroy

  accepts_nested_attributes_for :observees, allow_destroy: true
  accepts_nested_attributes_for :observation_ratings, allow_destroy: true
  
  enum :privacy_level, {
    observer_only: 'observer_only',              # 🔒 Only observer (private notes/journal)
    observed_only: 'observed_only',              # 👤 Observer + observed (1-on-1 feedback)
    managers_only: 'managers_only',              # 👔 Observer + observed's managers (NOT the observed)
    observed_and_managers: 'observed_and_managers',      # 👥 Observer + observed + managers (full transparency)
    public_observation: 'public_observation'         # 🌍 Everyone in organization + anyone with permalink
  }
  
  validates :observer, :company, presence: true
  validates :story, presence: true, if: :published?
  validates :privacy_level, presence: true
  before_validation { self.primary_feeling = nil if primary_feeling.blank? }
  before_validation { self.secondary_feeling = nil if primary_feeling.blank? }
  before_validation { self.custom_slug = nil if primary_feeling.blank? }
  validates :custom_slug, uniqueness: true, allow_nil: true
  validates :primary_feeling, inclusion: { in: Feelings::FEELINGS.map { |f| f[:discrete_feeling].to_s } }, allow_nil: true
  validates :secondary_feeling, inclusion: { in: Feelings::FEELINGS.map { |f| f[:discrete_feeling].to_s } }, allow_nil: true
  
  validate :observer_and_observees_in_same_company
  
  scope :recent, -> { order(observed_at: :desc) }
  scope :journal, -> { where(privacy_level: :observer_only) }
  scope :public_observations, -> { where(privacy_level: :public_observation) }
  scope :for_company, ->(company) { where(company: company) }
  scope :by_observer, ->(observer) { where(observer: observer) }
  scope :by_feeling, ->(feeling) { where(primary_feeling: feeling) }
  scope :by_privacy_level, ->(level) { where(privacy_level: level) }
  scope :drafts, -> { where(published_at: nil) }
  scope :published, -> { where.not(published_at: nil) }
  
  before_validation :set_observed_at_default
  after_update :update_channel_notifications_if_needed
  
  def permalink_id
    base_id = "#{observed_at.strftime('%Y-%m-%d')}-#{id}"
    custom_slug.present? ? "#{base_id}-#{custom_slug}" : base_id
  end
  
  def self.find_by_permalink_id(permalink_id)
    # Parse the permalink_id to extract date, id, and optional slug
    # Format: "2025-10-05-142" or "2025-10-05-142-custom-slug"
    parts = permalink_id.split('-')
    return nil if parts.length < 3
    
    date_part = "#{parts[0]}-#{parts[1]}-#{parts[2]}"
    id_part = parts[3]
    
    # Find observation by date and id (ignore slug)
    where(
      "DATE(observed_at) = ? AND id = ?", 
      Date.parse(date_part), 
      id_part.to_i
    ).first
  end
  
  def feelings_display
    Feelings.hydrate_and_sentencify(primary_feeling, secondary_feeling)
  end
  
  def positive_ratings
    observation_ratings.positive
  end
  
  def negative_ratings
    observation_ratings.negative
  end
  
  def has_negative_ratings?
    negative_ratings.exists?
  end
  
  def soft_delete!
    update!(deleted_at: Time.current)
  end

  def restore!
    update!(deleted_at: nil)
  end

  def soft_deleted?
    deleted_at.present?
  end
  
  def draft?
    published_at.nil?
  end
  
  def published?
    published_at.present?
  end
  
  def publish!
    update!(published_at: Time.current)
  end
  
  def can_post_to_slack?
    # Only public observations can be posted to channels
    # DMs can be sent for any observation where observees have Slack identities
    return true if privacy_level == 'public_observation'
    
    # For non-public observations, check if any observees have Slack identities
    observed_teammates.any? do |teammate|
      teammate.person.person_identities.exists?(provider: 'slack')
    end
  end
  
  private
  
  def set_observed_at_default
    self.observed_at ||= Time.current
  end
  
  def observer_and_observees_in_same_company
    return unless observer && company
    
    observees.each do |observee|
      unless observee.teammate.organization == company
        errors.add(:observees, "must be in the same company as the observer")
        break
      end
    end
  end

  def update_channel_notifications_if_needed
    # Only update if observation is still public and published
    return unless privacy_level == 'public_observation' && published?
    
    # Check if relevant attributes changed (not just metadata like updated_at)
    relevant_changes = saved_change_to_story? || 
                       saved_change_to_primary_feeling? || 
                       saved_change_to_secondary_feeling? ||
                       saved_change_to_story_extras?
    
    if relevant_changes
      # Find all organizations that have channel notifications for this observation
      channel_notifications = notifications
                                .where(notification_type: 'observation_channel')
                                .where("metadata->>'is_main_message' = 'true'")
                                .successful
      
      channel_notifications.each do |notification|
        organization_id = notification.metadata['organization_id']
        if organization_id.present?
          Observations::PostNotificationJob.perform_and_get_result(id, [], organization_id)
        end
      end
    end
  end
  
  # pg_search configuration
  pg_search_scope :search_by_full_text,
    against: {
      story: 'A',
      primary_feeling: 'B',
      secondary_feeling: 'B'
    },
    using: {
      tsearch: { prefix: true, any_word: true }
    }
  
  multisearchable against: [:story, :primary_feeling, :secondary_feeling]
end
