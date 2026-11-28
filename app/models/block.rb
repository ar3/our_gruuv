# frozen_string_literal: true

class Block < ApplicationRecord
  BLOCK_TYPES = %w[text].freeze

  belongs_to :document, inverse_of: :blocks

  before_validation :ensure_uuid
  before_validation :ensure_position

  validates :uuid, presence: true, uniqueness: true
  validates :block_type, presence: true, inclusion: { in: BLOCK_TYPES }
  validates :position, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :settings, exclusion: { in: [nil] }

  def typed
    Blocks::Registry.fetch(block_type).new(self)
  end

  def to_markdown
    typed.to_markdown
  end

  private

  def ensure_uuid
    self.uuid ||= SecureRandom.uuid
  end

  def ensure_position
    return if position.present?
    return unless document

    max_position = document.blocks.maximum(:position) || 0
    self.position = max_position + 1
  end
end
