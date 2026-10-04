# frozen_string_literal: true

class MaapProposal < ApplicationRecord
  STATUSES = %w[draft submitted applied rejected].freeze
  KINDS = %w[edit create].freeze
  SOURCES = %w[in_product markdown].freeze
  OPEN_STATUSES = %w[draft submitted].freeze
  VERSION_TYPES = %w[fundamental clarifying insignificant].freeze

  belongs_to :organization
  belongs_to :proposable, polymorphic: true, optional: true
  belongs_to :proposer, class_name: "CompanyTeammate"
  belongs_to :decided_by, class_name: "CompanyTeammate", optional: true

  has_many :child_proposal_links,
           class_name: "MaapProposalLink",
           foreign_key: :parent_proposal_id,
           dependent: :destroy,
           inverse_of: :parent_proposal
  has_many :child_proposals, through: :child_proposal_links, source: :child_proposal
  has_many :parent_proposal_links,
           class_name: "MaapProposalLink",
           foreign_key: :child_proposal_id,
           dependent: :destroy,
           inverse_of: :child_proposal
  has_many :parent_proposals, through: :parent_proposal_links, source: :parent_proposal

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :kind, presence: true, inclusion: { in: KINDS }
  validates :source, presence: true, inclusion: { in: SOURCES }
  validates :proposed_payload, presence: true
  validates :content_schema_version, presence: true
  validates :applied_version_type, inclusion: { in: VERSION_TYPES }, allow_nil: true
  validates :create_key, presence: true, if: :create_kind?
  validates :create_key,
            uniqueness: {
              scope: :organization_id,
              conditions: -> { where(status: OPEN_STATUSES) }
            },
            allow_nil: true
  validates :proposable, presence: true, if: :edit_kind?
  validate :proposer_belongs_to_organization
  validate :proposable_belongs_to_organization
  validate :create_has_no_proposable_until_applied

  scope :drafts, -> { where(status: "draft") }
  scope :submitted, -> { where(status: "submitted") }
  scope :open_proposals, -> { where(status: OPEN_STATUSES) }
  scope :decided, -> { where(status: %w[applied rejected]) }
  scope :edits, -> { where(kind: "edit") }
  scope :creates, -> { where(kind: "create") }
  scope :assignment_creates, -> { creates.where(proposable_type: [nil, "Assignment"]) }
  scope :ability_creates, -> { creates.where(proposable_type: "Ability") }
  scope :seat_creates, -> { creates.where(proposable_type: "Seat") }
  scope :title_creates, -> { creates.where(proposable_type: "Title") }
  scope :team_creates, -> { creates.where(proposable_type: "Team") }
  scope :position_creates, -> { creates.where(proposable_type: "Position") }
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

  def edit_kind?
    kind == "edit"
  end

  def create_kind?
    kind == "create"
  end

  def ability_create?
    create_kind? && proposable_type == "Ability"
  end

  def assignment_create?
    create_kind? && (proposable_type.blank? || proposable_type == "Assignment")
  end

  def seat_create?
    create_kind? && proposable_type == "Seat"
  end

  def title_create?
    create_kind? && proposable_type == "Title"
  end

  def team_create?
    create_kind? && proposable_type == "Team"
  end

  def position_create?
    create_kind? && proposable_type == "Position"
  end

  def link_child!(child_proposal, role:)
    child_proposal_links.find_or_create_by!(child_proposal: child_proposal, role: role.to_s)
  end

  def children_for_role(role)
    child_proposal_links.where(role: role.to_s).includes(:child_proposal).map(&:child_proposal)
  end

  def seat_apply_blockers
    return [] unless seat_create?

    blockers = []
    children_for_role("title").each do |child|
      next if child.applied?

      blockers << "Title proposal ##{child.id} must be applied before this Seat can be applied"
    end
    children_for_role("team").each do |child|
      next if child.applied?

      blockers << "Team proposal ##{child.id} must be applied before this Seat can be applied"
    end
    blockers
  end

  # Seat create drafts that still depend on a new Title cannot be submitted until that Title
  # exists and this proposal's title_id points at it.
  def seat_submit_blockers
    return [] unless seat_create?
    return [] unless draft?

    payload = proposed_payload.is_a?(Hash) ? proposed_payload : {}
    title_id = payload["title_id"].presence
    return [] if title_id.present?

    title_children = children_for_role("title")
    pending_title = title_children.find { |child| !child.applied? }
    if pending_title
      return [
        "The Title must be created first. Apply the linked Title proposal, then edit this " \
        "Seat proposal to associate with that Title before submitting."
      ]
    end

    applied_title = title_children.find(&:applied?)
    if applied_title || payload["title_proposal_id"].present? || payload["pending_title_name"].present?
      return [
        "Edit this Seat proposal to associate with the created Title before submitting."
      ]
    end

    []
  end

  def parent_seat_create_proposal
    parent_proposals.find(&:seat_create?)
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

  def proposed_title
    return "" unless proposed_payload.is_a?(Hash)

    named = proposed_payload["title"].presence ||
            proposed_payload["name"].presence ||
            proposed_payload["external_title"].presence
    return named if named.present?

    if proposable_type == "Seat" || proposed_payload.key?("seat_needed_by") || proposed_payload.key?("title_id")
      title_name = Title.find_by(id: proposed_payload["title_id"])&.external_title ||
                   proposed_payload["pending_title_name"].presence ||
                   "Seat"
      needed_by = proposed_payload["seat_needed_by"].to_s
      return needed_by.present? ? "#{title_name} - #{needed_by}" : title_name
    end

    ""
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

  def create_has_no_proposable_until_applied
    return unless create_kind?
    return if applied?
    return if proposable.blank?

    errors.add(:proposable, "must be blank until a create proposal is applied")
  end
end
