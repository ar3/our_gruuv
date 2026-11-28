# frozen_string_literal: true

class Document < ApplicationRecord
  OWNER_TYPES = %w[CompanyTeammate Team Department Organization].freeze

  # Closed vocabulary: one primary kind per document. Announcement + training_record
  # are historical / dated and exempt from the future staleness meter.
  # At most 3 kinds per KIND_GROUPS row.
  KINDS = %w[
    faq_reference
    troubleshooting
    how_to
    policy_process
    playbook
    profile
    announcement
    training_record
    generic
  ].freeze

  KIND_LABELS = {
    "faq_reference" => "FAQ / Reference",
    "troubleshooting" => "Troubleshooting",
    "how_to" => "How-to / SOP",
    "policy_process" => "Policy / Process",
    "playbook" => "Playbook / Handbook",
    "profile" => "Profile",
    "announcement" => "Announcement",
    "training_record" => "Training record",
    "generic" => "Generic"
  }.freeze

  KIND_DESCRIPTIONS = {
    "faq_reference" => "Long-lived definitions, glossaries, matrices, question-answer combos, and data dictionaries.",
    "troubleshooting" => "Symptom → cause → fix → escalate. Indexed by symptom, not title.",
    "how_to" => "Single-actor numbered steps to complete one task (often UI-sensitive).",
    "policy_process" => "Rules and workflows that govern behavior; often with trigger, handoffs, decisions, and escalation.",
    "playbook" => "Judgment, guidance, and 'try this' styled doc (handbooks, cheat sheets, battlecards, etc).",
    "profile" => "Team charters, “working with me” docs, etc; that explain who we are and what we stand for as a team or person.",
    "announcement" => "Company, Department, or Team update, that is historical by design. Does not go 'stale'... but should link to/embed a different kind of doc for what stays true.",
    "training_record" => "Company, Department, or Team date-stamped session (deck/recording). Does not go 'stale'... but should link to/embed a different kind of doc for what stays true.",
    "generic" => "Honestly something like gDocs, Word, etc might be better for these types of docs."
  }.freeze

  # Display groups for the kind picker (order matters). Max 3 kinds each.
  # freshness_popover explains Healthy → Warning → Needs Attention (time vs reactions).
  KIND_GROUPS = [
    {
      key: "daily",
      title: "Used day to day",
      freshness_popover: "Document health moves Healthy → Warning → Needs Attention. " \
                        "Warning after 60 days and Needs Attention after 90 without an owner re-verify " \
                        "or positive viewer reactions... whichever path hits first. " \
                        "Viewers can react on helpfulness and trustworthiness; " \
                        "3 negative reactions in a row (last 3, either axis) also drop health one level. " \
                        "It is a race between time and negative reactions.",
      kinds: %w[faq_reference troubleshooting how_to]
    },
    {
      key: "stable",
      title: "Change infrequently",
      freshness_popover: "Document health moves Healthy → Warning → Needs Attention. " \
                        "Warning after 6 months and Needs Attention after 9 without an owner re-verify " \
                        "or positive viewer reactions... whichever path hits first. " \
                        "Viewers can react on helpfulness and trustworthiness; " \
                        "3 negative reactions in a row (last 3, either axis) also drop health one level. " \
                        "It is a race between time and negative reactions.",
      kinds: %w[policy_process playbook profile]
    },
    {
      key: "historical",
      title: "Dated",
      freshness_popover: "These documents are historical by design. Health moves to Warning after 1 year. " \
                        "Needs Attention only when viewers leave enough negative reactions " \
                        "(3 negative in a row in the last 3... either helpfulness or trustworthiness). " \
                        "Viewers can react; owner re-verify is not the main clock here. " \
                        "It is still a race between time (to Warning) and negative reactions (to Needs Attention).",
      kinds: %w[announcement training_record generic]
    }
  ].freeze

  # Dated kinds do not use owner re-verify the same way; calendar warning + reaction-driven attention.
  STALENESS_EXEMPT_KINDS = %w[announcement training_record generic].freeze

  FRESHNESS_STATUSES = %w[healthy warning needs_attention].freeze

  belongs_to :organization
  belongs_to :owner, polymorphic: true

  has_many :blocks, -> { order(:position, :id) }, dependent: :destroy, inverse_of: :document
  has_many :document_links, dependent: :destroy, inverse_of: :document
  has_many :linked_assignments,
           through: :document_links,
           source: :linkable,
           source_type: "Assignment"

  accepts_nested_attributes_for :blocks, allow_destroy: true

  before_validation :normalize_owner_type
  before_validation :ensure_published_at

  validates :title, presence: true
  validates :kind, presence: true, inclusion: { in: KINDS }
  validates :owner_type, presence: true, inclusion: { in: OWNER_TYPES }
  validates :owner, presence: true
  validate :owner_belongs_to_organization

  scope :for_organization, ->(organization) { where(organization: organization) }
  scope :ordered, -> { order(:title) }

  attr_accessor :body
  attr_accessor :owner_key
  attr_accessor :assignment_ids_to_link

  after_initialize :hydrate_body_from_blocks, if: :persisted?
  after_save :sync_body_to_text_block
  after_save :sync_assignment_links

  def to_param
    "#{id}-#{title.to_s.parameterize}"
  end

  def kind_label
    self.class.kind_label(kind)
  end

  def self.kind_label(kind)
    KIND_LABELS[kind.to_s] || kind.to_s.humanize
  end

  def kind_description
    self.class.kind_description(kind)
  end

  def self.kind_description(kind)
    KIND_DESCRIPTIONS[kind.to_s]
  end

  def staleness_exempt?
    STALENESS_EXEMPT_KINDS.include?(kind.to_s)
  end

  def to_markdown
    lines = []
    lines << "# #{title}"
    lines << ""
    lines << "Kind: #{kind}"
    lines << "Owner: #{owner_display_name}"
    lines << ""
    blocks.each do |block|
      lines << "<!-- block:#{block.uuid} -->"
      lines << block.to_markdown
      lines << ""
    end
    lines.join("\n").strip
  end

  def owner_display_name
    case owner
    when CompanyTeammate
      owner.person&.display_name.presence || owner.person&.full_name.presence || "Teammate ##{owner.id}"
    when Organization, Department, Team
      owner.try(:display_name).presence || owner.try(:name).presence || "#{owner_type} ##{owner_id}"
    else
      "#{owner_type} ##{owner_id}"
    end
  end

  def owner_key_value
    return owner_key if owner_key.present?
    return nil unless owner_type.present? && owner_id.present?

    "#{owner_type}_#{owner_id}"
  end

  def assign_owner_from_key!(key)
    self.owner_key = key
    type, id = self.class.parse_owner_key(key)
    self.owner_type = type
    self.owner_id = id
  end

  def self.parse_owner_key(key)
    return [nil, nil] if key.blank?

    match = key.to_s.match(/\A(CompanyTeammate|Team|Department|Organization)_(\d+)\z/)
    return [nil, nil] unless match

    [match[1], match[2].to_i]
  end

  def primary_text_block
    blocks.detect { |block| block.block_type == "text" } || blocks.first
  end

  private

  def normalize_owner_type
    assign_owner_from_key!(owner_key) if owner_key.present?
  end

  def ensure_published_at
    self.published_at ||= Time.current
  end

  def owner_belongs_to_organization
    return if owner.blank? || organization.blank?

    owner_org_id = case owner
                   when CompanyTeammate
                     owner.organization_id
                   when Organization
                     owner.id
                   when Department, Team
                     owner.company_id
                   end

    return if owner_org_id == organization_id

    errors.add(:owner, "must belong to the same organization")
  end

  def hydrate_body_from_blocks
    return if body.present?

    self.body = primary_text_block&.content
  end

  def sync_body_to_text_block
    return if body.nil?

    block = primary_text_block
    if block
      block.update!(content: body) if block.content != body
    else
      blocks.create!(
        block_type: "text",
        position: 1,
        content: body,
        settings: {}
      )
    end
  end

  def sync_assignment_links
    return if assignment_ids_to_link.nil?

    desired_ids = Array(assignment_ids_to_link).map(&:presence).compact.map(&:to_i).uniq
    valid_ids = organization.assignments.where(id: desired_ids).pluck(:id)

    existing = document_links.where(linkable_type: "Assignment")
    existing.where.not(linkable_id: valid_ids).destroy_all

    existing_ids = document_links.where(linkable_type: "Assignment").pluck(:linkable_id)
    (valid_ids - existing_ids).each do |assignment_id|
      document_links.create!(linkable_type: "Assignment", linkable_id: assignment_id)
    end
  end
end
