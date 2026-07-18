# frozen_string_literal: true

class LlmInvocation < ApplicationRecord
  STATUSES = %w[pending processing completed failed].freeze

  belongs_to :organization, class_name: 'Organization', optional: true
  belongs_to :triggered_by_teammate, class_name: 'CompanyTeammate', optional: true
  belongs_to :parent, polymorphic: true, optional: true

  has_one_attached :request_payload
  has_one_attached :response_payload

  validates :purpose, :model_id, :status, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :completed, -> { where(status: 'completed') }
end
