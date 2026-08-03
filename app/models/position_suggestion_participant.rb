# frozen_string_literal: true

class PositionSuggestionParticipant < ApplicationRecord
  PARTICIPATION_STATUSES = %w[active done_contributing withdrawn].freeze

  belongs_to :position_suggestion
  belongs_to :company_teammate

  validates :participation_status, presence: true, inclusion: { in: PARTICIPATION_STATUSES }
  validates :company_teammate_id, uniqueness: { scope: :position_suggestion_id }

  scope :active, -> { where(participation_status: "active") }
  scope :done_contributing, -> { where(participation_status: "done_contributing") }
  scope :withdrawn, -> { where(participation_status: "withdrawn") }
  scope :not_withdrawn, -> { where.not(participation_status: "withdrawn") }

  def active?
    participation_status == "active"
  end

  def done_contributing?
    participation_status == "done_contributing"
  end

  def withdrawn?
    participation_status == "withdrawn"
  end

  def mark_done_contributing!
    update!(participation_status: "done_contributing")
  end

  def mark_active!
    update!(participation_status: "active")
  end

  def withdraw!
    update!(participation_status: "withdrawn")
  end
end
