# frozen_string_literal: true

class MaapProposal < ApplicationRecord
  STATUSES = %w[draft submitted applied rejected].freeze
  KINDS = %w[edit].freeze
  SOURCES = %w[in_product markdown].freeze
  OPEN_STATUSES = %w[draft submitted].freeze
  VERSION_TYPES = %w[fundamental clarifying insignificant].freeze

  belongs_to :organization
  belongs_to :proposable, polymorphic: true
  belongs_to :proposer, class_name: "CompanyTeammate"
  belongs_to :decided_by, class_name: "CompanyTeammate", optional: true

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :kind, presence: true, inclusion: { in: KINDS }
  validates :source, presence: true, inclusion: { in: SOURCES }
  validates :proposed_payload, presence: true
  validates :content_schema_version, presence: true
  validates :applied_version_type, inclusion: { in: VERSION_TYPES }, allow_nil: true
  validate :proposer_belongs_to_organization
  validate :proposable_belongs_to_organization

  scope :drafts, -> { where(status: "draft") }
  scope :submitted, -> { where(status: "submitted") }
  scope :open_proposals, -> { where(status: OPEN_STATUSES) }
  scope :decided, -> { where(status: %w[applied rejected]) }
  scope :recent_first, -> { order(updated_at: :desc) }
  scope :created_first, -> { order(created_at: :desc) }
  scope :with_statuses, ->(statuses) {
    normalized = Array(statuses).map(&:to_s) & STATUSES
    normalized.empty? ? none : where(status: normalized)
  }
  scope :for_organization, ->(organization) { where(organization: organization) }
  scope :for_proposable, ->(proposable) {
    where(proposable_type: proposable.class.base_class.name, proposable_id: proposable.id)
  }

  def draft?
    status == "draft"
  end

  def submitted?
    status == "submitted"
  end

  def applied?
    status == "applied"
  end

  def rejected?
    status == "rejected"
  end

  def open?
    OPEN_STATUSES.include?(status)
  end

  def deletable?
    open?
  end

  def editable?
    draft?
  end

  def submittable?
    draft?
  end

  def decidable?
    submitted?
  end

  private

  def proposer_belongs_to_organization
    return unless proposer && organization

    return if proposer.organization_id == organization_id

    errors.add(:proposer, "must belong to the organization")
  end

  def proposable_belongs_to_organization
    return unless proposable && organization

    company_id = if proposable.respond_to?(:company_id)
      proposable.company_id
    elsif proposable.respond_to?(:organization_id)
      proposable.organization_id
    end

    return if company_id == organization_id

    errors.add(:proposable, "must belong to the organization")
  end
end
