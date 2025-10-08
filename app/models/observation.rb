class Observation < ApplicationRecord
  include Notifiable
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
  
  validates :observer, :company, :story, :privacy_level, presence: true
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
  
  before_validation :set_observed_at_default
  
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
  
end
