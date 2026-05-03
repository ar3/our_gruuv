class Position < ApplicationRecord
  include PgSearch::Model
  include ModelSemanticVersionable

  # Associations
  belongs_to :title
  belongs_to :position_level
  belongs_to :position_eligibility_requirement, optional: true
  has_many :position_assignments, dependent: :destroy
  has_many :assignments, through: :position_assignments
  has_many :position_abilities, dependent: :destroy
  has_many :abilities, through: :position_abilities
  has_many :comments, as: :commentable, dependent: :destroy
  has_many :maap_agent_runs, as: :subject, dependent: :destroy
  has_one :position_clarity_maap_agent_run,
          -> { where(agent_kind: MaapAgentRun::AGENT_KIND_POSITION_CLARITY) },
          class_name: 'MaapAgentRun',
          as: :subject
  has_one :published_external_reference, -> { where(reference_type: 'published') }, 
          class_name: 'ExternalReference', as: :referable, dependent: :destroy
  has_one :draft_external_reference, -> { where(reference_type: 'draft') }, 
          class_name: 'ExternalReference', as: :referable, dependent: :destroy
  
  # Validations
  validates :title, presence: true
  validates :position_level, presence: true
  validates :position_level, uniqueness: { scope: :title_id }
  validates :position_level, inclusion: { in: ->(position) { position.title&.position_major_level&.position_levels || [] } }
  
  # Scopes
  scope :unarchived, -> { where(deleted_at: nil) }
  scope :archived, -> { where.not(deleted_at: nil) }
  scope :ordered, -> { joins(:title, :position_level).order('titles.external_title, position_levels.level') }
  scope :for_company, ->(company) { joins(:title).where(titles: { company_id: company.id }) }

  # Archive (soft delete) – block if position_assignments, position_abilities, or active employment_tenures exist
  def archived?
    deleted_at.present?
  end

  def archive!
    update!(deleted_at: Time.current)
  end

  def restore!
    update!(deleted_at: nil)
  end

  def archivable?
    position_assignments.empty? &&
      position_abilities.empty? &&
      EmploymentTenure.where(position: self).active.empty?
  end

  # Finder method that handles both id and id-name formats
  def self.find_by_param(param)
    # If param is just a number, use it as id
    return find(param) if param.to_s.match?(/\A\d+\z/)
    
    # Otherwise, extract id from id-name format
    id = param.to_s.split('-').first
    find(id)
  end
  
  # Instance methods
  def display_name_with_version
    "#{display_name} v#{semantic_version}"
  end

  def display_name
    "#{title.external_title} - #{position_level.level}"
  end

  def to_s
    display_name
  end

  def to_param
    "#{id}-#{display_name.parameterize}"
  end
  
  def company
    title.company
  end
  
  def required_assignments
    position_assignments.where(assignment_type: 'required').includes(:assignment)
  end
  
  def suggested_assignments
    position_assignments.where(assignment_type: 'suggested').includes(:assignment)
  end
  
  def required_assignments_count
    position_assignments.where(assignment_type: 'required').count
  end
  
  def suggested_assignments_count
    position_assignments.where(assignment_type: 'suggested').count
  end
  
  # External reference convenience methods
  def published_url
    published_external_reference&.url
  end
  
  def draft_url
    draft_external_reference&.url
  end

  # Summary for job description and public views: title summary first, then position summary.
  def combined_summary
    parts = [title&.position_summary, position_summary].compact_blank
    return nil if parts.empty?
    parts.join("\n\n")
  end

  # Serialized bundle of linked assignments for PaperTrail (+object_changes+) — same idea as
  # Assignment#outcomes_audit_snapshot / +computed_outcomes_audit_snapshot+.
  def computed_assignments_audit_snapshot
    pas = position_assignments.includes(:assignment).to_a.sort_by do |pa|
      [pa.assignment_type, pa.assignment&.title.to_s.downcase]
    end
    return '(no position assignments)' if pas.empty?

    pas.map do |pa|
      assignment_title = pa.assignment&.title.presence || "Assignment ##{pa.assignment_id}"
      "#{pa.assignment_type} — #{assignment_title} — #{pa.energy_range_display}"
    end.join("\n")
  end

  # Persists the bundle without creating a PaperTrail version (e.g. scripts, backfills).
  def refresh_assignments_audit_snapshot_column!
    update_column(:assignments_audit_snapshot, computed_assignments_audit_snapshot)
  end

  # Creates a PaperTrail version when position assignments are saved/deleted without editing position columns.
  # Stores the assignments bundle on +assignments_audit_snapshot+ so +object_changes+ lists it like a normal attribute,
  # and bumps patch semantic version (cf. Assignment#record_version_for_outcome_changes!).
  def record_version_for_assignment_changes!(change_context: 'Position assignments updated')
    snapshot = computed_assignments_audit_snapshot

    ci = PaperTrail.request.controller_info || {}
    PaperTrail.request.controller_info = ci.merge(
      position_assignment_change_context: change_context
    )

    update!(
      assignments_audit_snapshot: snapshot,
      semantic_version: next_patch_version
    )
  end

  # pg_search configuration
  pg_search_scope :search_by_full_text,
    associated_against: {
      title: [:external_title],
      position_level: [:level]
    },
    using: {
      tsearch: { prefix: true, any_word: true }
    }
  
  multisearchable against: [],
    associated_against: {
      title: [:external_title],
      position_level: [:level]
    }
  
end