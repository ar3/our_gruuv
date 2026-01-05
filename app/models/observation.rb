class Observation < ApplicationRecord
  include Notifiable
  include PgSearch::Model
  include ObservationRatingFormatter
  has_paper_trail
  
  belongs_to :observer, class_name: 'Person'
  belongs_to :company, class_name: 'Organization'
  belongs_to :observation_trigger, optional: true
  belongs_to :observable_moment, optional: true
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
    public_to_company: 'public_to_company',         # 🏢 All authenticated company members
    public_to_world: 'public_to_world'         # 🌍 Everyone including unauthenticated (public permalinks)
  }
  
  enum :observation_type, {
    generic: 'generic',
    kudos: 'kudos',
    feedback: 'feedback',
    quick_note: 'quick_note'
  }, suffix: true
  
  # created_as_type is just a string, not an enum (never changes after creation)
  
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
  scope :public_observations, -> { where(privacy_level: :public_to_world) }
  scope :company_wide, -> { where(privacy_level: :public_to_company) }
  scope :for_company, ->(company) { where(company: company) }
  scope :by_observer, ->(observer) { where(observer: observer) }
  scope :by_feeling, ->(feeling) { where(primary_feeling: feeling) }
  scope :by_privacy_level, ->(level) { where(privacy_level: level) }
  scope :drafts, -> { where(published_at: nil) }
  scope :published, -> { where.not(published_at: nil) }
  scope :kudos_observations, -> { where(observation_type: 'kudos') }
  scope :feedback_observations, -> { where(observation_type: 'feedback') }
  scope :quick_notes, -> { where(observation_type: 'quick_note') }
  scope :generic_observations, -> { where(observation_type: 'generic') }
  scope :created_as_kudos, -> { where(created_as_type: 'kudos') }
  scope :created_as_feedback, -> { where(created_as_type: 'feedback') }
  scope :with_observable_moments, -> { where.not(observable_moment_id: nil) }
  scope :without_observable_moments, -> { where(observable_moment_id: nil) }
  scope :for_moment_type, ->(type) { joins(:observable_moment).where(observable_moments: { moment_type: type }) }
  scope :soft_deleted, -> { where.not(deleted_at: nil) }
  scope :not_soft_deleted, -> { where(deleted_at: nil) }
  
  before_validation :set_observed_at_default
  after_save :mark_observable_moment_as_processed, if: -> { observable_moment.present? && saved_change_to_published_at? && published? }
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
  
  def can_post_to_slack_channel?
    # Only public observations (company-wide or world-wide) can be posted to channels
    # DMs can be sent for any observation where observees have Slack identities
    privacy_level == 'public_to_company' || privacy_level == 'public_to_world'
  end
  
  private
  
  def set_observed_at_default
    self.observed_at ||= Time.current
  end
  
  def observer_and_observees_in_same_company
    return unless observer && company
    
    # Allow moment-based observations to bypass this validation if moment provides context
    # Check both the ID and the association to handle cases where association isn't loaded yet
    if observable_moment_id.present? || observable_moment.present?
      return
    end
    
    observees.each do |observee|
      unless observee.teammate.organization == company
        errors.add(:observees, "must be in the same company as the observer")
        break
      end
    end
  end
  
  def mark_observable_moment_as_processed
    return unless observable_moment
    return if observable_moment.processed?
    
    # Get current user's teammate for processed_by_teammate
    current_teammate = if observer
      observer.teammates.find_by(organization: company)
    end
    
    observable_moment.update!(
      processed_at: Time.current,
      processed_by_teammate: current_teammate
    )
  end

  def update_channel_notifications_if_needed
    # Only update if observation is still public (company or world) and published
    return unless (privacy_level == 'public_to_company' || privacy_level == 'public_to_world') && published?
    
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
