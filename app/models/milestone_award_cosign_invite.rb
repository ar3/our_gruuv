# frozen_string_literal: true

class MilestoneAwardCosignInvite < ApplicationRecord
  belongs_to :milestone_award
  belongs_to :invitee_teammate, class_name: "CompanyTeammate"
  belongs_to :feedback_request, optional: true

  validates :invitee_teammate_id, uniqueness: { scope: :milestone_award_id }

  scope :open, -> { where(declined_at: nil, converted_to_feedback_at: nil) }
  scope :declined, -> { where.not(declined_at: nil) }
  scope :converted, -> { where.not(converted_to_feedback_at: nil) }
  scope :awaiting_response, lambda {
    open.joins(:milestone_award).where(
      milestone_awards: { cosigner_signed_at: nil }
    ).where(
      <<~SQL.squish
        milestone_awards.cosign_requested_at IS NOT NULL
        AND (
          milestone_awards.awarder_skipped_cosign_at IS NULL
          OR milestone_awards.moderator_requires_cosign_at IS NOT NULL
        )
      SQL
    )
  }

  def open?
    declined_at.blank? && converted_to_feedback_at.blank?
  end

  def declined?
    declined_at.present?
  end

  def converted_to_feedback?
    converted_to_feedback_at.present?
  end
end
