# frozen_string_literal: true

class PositionSuggestion < ApplicationRecord
  STATUSES = %w[open completed].freeze

  belongs_to :position
  belongs_to :organization
  belongs_to :opened_by, class_name: "CompanyTeammate"
  belongs_to :closed_by, class_name: "CompanyTeammate", optional: true

  has_many :participants, class_name: "PositionSuggestionParticipant", dependent: :destroy
  has_many :company_teammates, through: :participants
  has_many :milestones, class_name: "PositionSuggestionMilestone", dependent: :destroy
  has_many :comments, dependent: :nullify

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :position, presence: true
  validates :organization, presence: true
  validates :opened_by, presence: true
  validate :position_belongs_to_organization
  validate :only_one_open_per_position, on: :create

  scope :open_sessions, -> { where(status: "open") }
  scope :completed_sessions, -> { where(status: "completed") }
  scope :for_organization, ->(organization) { where(organization: organization) }
  scope :recent_first, -> { order(updated_at: :desc) }

  def open?
    status == "open"
  end

  def completed?
    status == "completed"
  end

  def active_participants
    participants.active
  end

  def participant_for(company_teammate)
    participants.find_by(company_teammate: company_teammate)
  end

  def unresolved_root_comments_by_active_participants
    active_person_ids = active_participants.includes(company_teammate: :person).map { |p| p.company_teammate.person_id }
    comments.root_comments.unresolved.where(creator_id: active_person_ids)
  end

  def can_complete?
    open? && unresolved_root_comments_by_active_participants.none?
  end

  def complete!(closed_by:)
    raise ArgumentError, "Suggestion is not open" unless open?
    raise ArgumentError, "Unresolved comments remain" unless can_complete?

    update!(
      status: "completed",
      closed_by: closed_by,
      closed_at: Time.current
    )
  end

  private

  def position_belongs_to_organization
    return unless position && organization

    company = organization.root_company || organization
    return if position.title&.company_id == company.id

    errors.add(:position, "must belong to the organization")
  end

  def only_one_open_per_position
    return unless open? && position_id.present?
    return unless self.class.open_sessions.where(position_id: position_id).where.not(id: id).exists?

    errors.add(:position, "already has an open suggestion session")
  end
end
