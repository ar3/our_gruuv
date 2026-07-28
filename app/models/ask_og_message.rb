# frozen_string_literal: true

class AskOgMessage < ApplicationRecord
  ROLES = %w[user assistant].freeze
  ROLE_USER = "user"
  ROLE_ASSISTANT = "assistant"

  belongs_to :ask_og_result

  validates :role, presence: true, inclusion: { in: ROLES }
  validates :body, presence: true
  validates :position, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :position, uniqueness: { scope: :ask_og_result_id }

  scope :ordered, -> { order(:position, :id) }
  scope :user_messages, -> { where(role: ROLE_USER) }
  scope :assistant_messages, -> { where(role: ROLE_ASSISTANT) }

  def user?
    role == ROLE_USER
  end

  def assistant?
    role == ROLE_ASSISTANT
  end
end
