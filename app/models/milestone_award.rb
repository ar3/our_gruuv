# frozen_string_literal: true

# Aggregate root for a milestone award action (normal or calibration fill-down).
# Evidence (co-sign / skip / moderator require-cosign) lives here; TeammateMilestone
# rows are children created on release (cosign or skip) and destroyed if a moderator
# later requires co-sign after a skip.
class MilestoneAward < ApplicationRecord
  include TypedNameSignature
  include Notifiable

  SOURCES = %w[normal calibration].freeze

  belongs_to :teammate, class_name: "CompanyTeammate"
  belongs_to :ability
  belongs_to :certifying_teammate, class_name: "CompanyTeammate"
  belongs_to :organization
  belongs_to :ability_milestone_calibration_item, optional: true
  belongs_to :cosigning_teammate, class_name: "CompanyTeammate", optional: true
  belongs_to :moderator_teammate, class_name: "CompanyTeammate", optional: true

  has_many :cosign_invites, class_name: "MilestoneAwardCosignInvite", dependent: :destroy
  has_many :teammate_milestones, dependent: :nullify

  validates :official_milestone_level, presence: true,
            numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: 5 }
  validates :source, presence: true, inclusion: { in: SOURCES }
  validates :awarder_typed_name, :awarder_signed_at, presence: true
  validates :privacy_level, inclusion: { in: %w[private company] }
  validate :awarder_typed_name_matches_person

  scope :pending_cosign, lambda {
    where.not(cosign_requested_at: nil)
      .where(cosigner_signed_at: nil, awarder_skipped_cosign_at: nil, moderator_requires_cosign_at: nil)
  }
  scope :skipped_awaiting_moderation, lambda {
    where.not(awarder_skipped_cosign_at: nil)
      .where(cosigner_signed_at: nil, moderator_requires_cosign_at: nil)
  }
  scope :requires_cosign_after_moderation, lambda {
    where.not(moderator_requires_cosign_at: nil).where(cosigner_signed_at: nil)
  }

  def pending_cosign?
    cosign_requested_at.present? &&
      cosigner_signed_at.blank? &&
      awarder_skipped_cosign_at.blank? &&
      moderator_requires_cosign_at.blank?
  end

  def skipped_cosign?
    awarder_skipped_cosign_at.present? && cosigner_signed_at.blank?
  end

  def skipped_awaiting_moderation?
    skipped_cosign? && moderator_requires_cosign_at.blank?
  end

  def cosigned?
    cosigner_signed_at.present?
  end

  def requires_cosign_after_moderation?
    moderator_requires_cosign_at.present? && cosigner_signed_at.blank?
  end

  def released?
    cosigned? || (skipped_cosign? && !requires_cosign_after_moderation?)
  end

  def effective?
    return false if pending_cosign?
    return false if requires_cosign_after_moderation?

    cosigned? || skipped_cosign?
  end

  def derived_status
    return :cosigned if cosigned?
    return :requires_cosign if requires_cosign_after_moderation?
    return :skipped_awaiting_moderation if skipped_awaiting_moderation?
    return :pending_cosign if pending_cosign?

    :draft
  end

  def primary_teammate_milestone
    teammate_milestones.order(milestone_level: :desc).first
  end

  def open_cosign_invites
    cosign_invites.open
  end

  def all_cosign_invitees_declined?
    cosign_invites.any? && cosign_invites.all?(&:declined?)
  end

  private

  def awarder_typed_name_matches_person
    return if typed_name_matches?(awarder_typed_name, certifying_teammate&.person)

    errors.add(:awarder_typed_name, "must match your full name")
  end
end
