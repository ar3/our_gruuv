class Ability < ApplicationRecord
  include PgSearch::Model
  has_paper_trail

  belongs_to :organization
  belongs_to :created_by, class_name: 'Person'
  belongs_to :updated_by, class_name: 'Person'
  has_many :assignment_abilities, dependent: :destroy
  has_many :assignments, through: :assignment_abilities
  has_many :teammate_milestones, dependent: :destroy
  has_many :people, through: :teammate_milestones
  has_many :observation_ratings, as: :rateable, dependent: :destroy
  has_many :observations, through: :observation_ratings

  # Scopes
  scope :ordered, -> { order(:name) }

  # Finder method that handles both id and id-name formats
  def self.find_by_param(param)
    # If param is just a number, use it as id
    return find(param) if param.to_s.match?(/\A\d+\z/)
    
    # Otherwise, extract id from id-name format
    id = param.to_s.split('-').first
    find(id)
  end

  # Person milestone-related methods
  def person_attainments
    teammate_milestones.by_milestone_level.includes(:person)
  end

  def person_attainments_count
    teammate_milestones.count
  end

  def has_person_attainments?
    teammate_milestones.exists?
  end

  def people_with_milestone(level)
    teammate_milestones.where(milestone_level: level).includes(:person).map(&:person)
  end

  def people_with_highest_milestone
    max_level = teammate_milestones.maximum(:milestone_level)
    return [] unless max_level
    
    teammate_milestones.where(milestone_level: max_level).includes(:person).map(&:person)
  end

  validates :name, presence: true, uniqueness: { scope: :organization_id }
  validates :description, presence: true
  validates :semantic_version, presence: true, format: { with: /\A\d+\.\d+\.\d+\z/, message: 'must be in semantic version format (e.g., 1.0.0)' }

  scope :for_organization, ->(org) { where(organization: org) }
  scope :recent, -> { order(updated_at: :desc) }

  # Version bumping methods
  def bump_major_version(reason)
    update!(semantic_version: next_major_version)
  end

  def bump_minor_version(reason)
    update!(semantic_version: next_minor_version)
  end

  def bump_patch_version(reason)
    update!(semantic_version: next_patch_version)
  end

  # Version calculation methods
  def next_major_version
    major, minor, patch = semantic_version.split('.').map(&:to_i)
    "#{major + 1}.0.0"
  end

  def next_minor_version
    major, minor, patch = semantic_version.split('.').map(&:to_i)
    "#{major}.#{minor + 1}.0"
  end

  def next_patch_version
    major, minor, patch = semantic_version.split('.').map(&:to_i)
    "#{major}.#{minor}.#{patch + 1}"
  end

  # Extract major version number from semantic_version
  def major_version
    semantic_version.split('.').first.to_i
  end

  # Version status methods
  def current_version?
    # The current version is the latest one (no newer versions exist)
    !versions.where('created_at > ?', updated_at).exists?
  end

  def deprecated?
    !current_version?
  end

  # Display methods
  def display_name
    "#{name} v#{semantic_version}"
  end

  def to_param
    "#{id}-#{name.parameterize}"
  end

  def version_with_guidance
    return display_name unless versions.any?

    latest_version = versions.last
    change_reason = latest_version.meta['change_reason']
    change_type = latest_version.meta['version_change_type']

    if change_reason && change_type
      "#{display_name} (#{change_type}: #{change_reason})"
    else
      display_name
    end
  end

  # Assignment-related methods
  def required_by_assignments
    assignment_abilities.by_milestone_level.includes(:assignment)
  end

  def required_by_assignments_count
    assignment_abilities.count
  end

  def is_required_by_assignments?
    assignment_abilities.exists?
  end

  def highest_milestone_required_by_assignment(assignment)
    assignment_abilities.where(assignment: assignment).maximum(:milestone_level)
  end

  # Milestone-related methods
  def milestone_description(level)
    return nil unless (1..5).include?(level)
    
    send("milestone_#{level}_description")
  end

  def defined_milestones
    (1..5).select { |level| milestone_description(level).present? }
  end

  def has_milestone_definition?(level)
    milestone_description(level).present?
  end

  def milestone_display(level)
    description = milestone_description(level)
    if description.present?
      "Milestone #{level}: #{description}"
    else
      "Milestone #{level}"
    end
  end

  
  # pg_search configuration
  pg_search_scope :search_by_full_text,
    against: {
      name: 'A',
      description: 'B'
    },
    using: {
      tsearch: { prefix: true, any_word: true }
    }
  
  multisearchable against: [:name, :description]
end
