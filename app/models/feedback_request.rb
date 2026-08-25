class FeedbackRequest < ApplicationRecord
  include Notifiable

  belongs_to :company, class_name: 'Organization'
  belongs_to :requestor_teammate, class_name: 'CompanyTeammate'
  belongs_to :subject_of_feedback_teammate, class_name: 'CompanyTeammate'
  has_many :feedback_request_questions, dependent: :destroy
  has_many :feedback_request_responders, dependent: :destroy
  has_many :responders, through: :feedback_request_responders, source: :company_teammate
  has_many :observations, through: :feedback_request_questions

  # Soft delete scopes (NO default_scope)
  scope :not_deleted, -> { where(deleted_at: nil) }
  scope :archived_soft_delete, -> { where.not(deleted_at: nil) }
  scope :open, -> { not_deleted }

  # Validations
  validates :company, :requestor_teammate_id, :subject_of_feedback_teammate_id, :subject_line, presence: true
  validates :open_to_anyone, inclusion: { in: [true, false] }

  attribute :open_to_anyone, :boolean, default: true

  # Soft delete methods
  def soft_delete!
    update!(deleted_at: Time.current)
  end

  def restore!
    update!(deleted_at: nil)
  end

  def open?
    !archived? && deleted_at.nil?
  end

  # Respondent-only requests need at least one named person who can answer.
  def requires_named_responders?
    !open_to_anyone?
  end

  # Check if any responders have answered (created observations)
  def has_responses?
    observations.exists?
  end

  # Get count of responders who have responded
  def responder_response_count
    observations.joins(:observer)
                 .joins("INNER JOIN teammates ON teammates.person_id = observations.observer_id")
                 .where("teammates.id IN (?)", responder_ids)
                 .select("DISTINCT teammates.id")
                 .count
  end

  # Get responders who haven't responded yet
  def unanswered_responders
    responded_teammate_ids = observations.joins(:observer)
                                         .joins("INNER JOIN teammates ON teammates.person_id = observations.observer_id")
                                         .where("teammates.id IN (?)", responder_ids)
                                         .select("DISTINCT teammates.id")
    responders.where.not(id: responded_teammate_ids)
  end

  # State determination based on attributes (no enum needed)
  # States: invalid, ready, active, archived

  def invalid?
    return true if feedback_request_questions.empty?
    return true if feedback_request_questions.any? { |q| q.question_text.blank? }
    return true if requires_named_responders? && responders.empty?

    false
  end

  def ready?
    # Ready if: valid but notifications haven't been sent
    !invalid? && !active? && !archived?
  end

  def active?
    # Active if: valid and notifications have been sent
    !invalid? && !archived? && notifications_sent?
  end

  def archived?
    # Archived if: soft deleted
    deleted_at.present?
  end

  # Get current state as string
  def state
    return 'archived' if archived?
    return 'invalid' if invalid?
    return 'active' if active?
    return 'ready' if ready?
    'invalid' # fallback
  end

  # Notifications sent to respondents (Slack DMs) for this feedback request.
  # Each notification has metadata['teammate_id'] so we can list who was notified and when.
  def respondent_notifications_sent
    notifications
      .where(notification_type: 'feedback_request', status: 'sent_successfully')
      .order(created_at: :desc)
  end

  # Check if notifications have been sent to responders
  def notifications_sent?
    # Check if there are any successful notifications for this feedback request
    # We'll use a notification_type like 'feedback_request' to identify them
    posted_to_slack?(sub_type: 'feedback_request')
  end

  # State-based helper methods
  def can_be_edited?
    invalid? || ready?
  end

  def can_add_responders?
    active? || ready?
  end

  # Answerable when configured (not invalid/archived).
  def answerable?
    !archived? && !invalid?
  end

  # Validation method (kept for compatibility, but doesn't update state anymore)
  def validate_state!
    # State is now computed, so this method is mainly for ensuring data integrity
    # Could raise errors or log warnings if invalid
    if invalid?
      Rails.logger.warn "FeedbackRequest #{id} is in invalid state"
    end
  end

  # Finder that accepts bare ids or human-readable id-slug params.
  def self.find_by_param(param)
    return find(param) if param.to_s.match?(/\A\d+\z/)

    id = param.to_s.split('-').first
    find(id)
  end

  def to_param
    slug_parts = []
    subject_name = subject_of_feedback_teammate&.person&.casual_name
    slug_parts << subject_name if subject_name.present?
    slug_parts << subject_line if subject_line.present?
    slug = slug_parts.map { |part| part.to_s.parameterize }.reject(&:blank?).join('-')
    slug.present? ? "#{id}-#{slug}" : id.to_s
  end
end
