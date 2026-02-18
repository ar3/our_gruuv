class Ability < ApplicationRecord
  include PgSearch::Model
  include ModelSemanticVersionable

  belongs_to :company, class_name: 'Organization'
  belongs_to :department, optional: true
  belongs_to :created_by, class_name: 'Person'
  belongs_to :updated_by, class_name: 'Person'
  has_many :assignment_abilities, dependent: :destroy
  has_many :assignments, through: :assignment_abilities
  has_many :position_abilities, dependent: :destroy
  has_many :positions, through: :position_abilities
  has_many :teammate_milestones, dependent: :destroy
  has_many :people, through: :teammate_milestones
  has_many :observation_ratings, as: :rateable, dependent: :destroy
  has_many :observations, through: :observation_ratings
  has_many :comments, as: :commentable, dependent: :destroy

  # Validations
  validates :name, presence: true, uniqueness: { scope: :company_id }
  validates :description, presence: true
  validate :department_must_belong_to_company

  # Scopes
  scope :unarchived, -> { where(deleted_at: nil) }
  scope :archived, -> { where.not(deleted_at: nil) }
  scope :ordered, -> { order(:name) }
  scope :for_company, ->(company) { where(company_id: company.is_a?(Integer) ? company : company.id) }
  scope :for_department, ->(department) { where(department: department) }
  scope :recent, -> { order(updated_at: :desc) }

  # Archive (soft delete) – block if position_abilities or assignment_abilities exist
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
    position_abilities.empty? && assignment_abilities.empty?
  end

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

  # Display methods
  def display_name
    "#{name} v#{semantic_version}"
  end

  def to_param
    "#{id}-#{name.parameterize}"
  end

  # Override the concern's version_with_guidance to use this model's display_name
  def version_with_guidance
    # Simplified version - PaperTrail metadata would require additional configuration
    display_name
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

  def required_by_positions
    position_abilities.by_milestone_level.includes(position: :title)
  end

  def required_by_positions_count
    position_abilities.count
  end

  def is_required_by_positions?
    position_abilities.exists?
  end

  def highest_milestone_required_by_assignment(assignment)
    assignment_abilities.where(assignment: assignment).maximum(:milestone_level)
  end

  # Default milestone description templates (used to prefill edit form when all five are blank)
  def self.default_milestone_description(level)
    return nil unless (1..5).include?(level)
    DEFAULT_MILESTONE_DESCRIPTIONS[level]
  end

  EXAMPLES_BLOCK = <<~EXAMPLES.strip
    -----

    ##### Examples

    | Example 1    | Example 2 |
    | --- | --- |
    | Example 3  | Example 4    |
    | Example 5 | Example 6     |

    *This is NOT a checklist, but instead a list of example activities or results that indicate a demonstration of this ability.*
  EXAMPLES

  DEFAULT_MILESTONE_DESCRIPTIONS = {
    1 => <<~TEXT.strip,
      I have observed this person showing a consistent, comfortable, continuous, and clear positive impact to a squad when wielding this ability, and therefore I would put them in situations where they can **employ this ability with only a small amount of guidance**

      #{EXAMPLES_BLOCK}
    TEXT
    2 => <<~TEXT.strip,
      I have observed this person showing a consistent, comfortable, continuous, and clear positive impact to a squad when wielding this ability, and therefore I would put them in situations where they can **employ this ability, with no assistance as well as being a trusted active or passive mentor to others**

      #{EXAMPLES_BLOCK}
    TEXT
    3 => <<~TEXT.strip,
      I have observed this person showing a consistent, comfortable, continuous, and clear positive impact to a squad when wielding this ability, and therefore I would put them in situations where they can **employ this ability as well as being considered an expert within this discipline**

      #{EXAMPLES_BLOCK}
    TEXT
    4 => <<~TEXT.strip,
      I have observed this person showing a consistent, comfortable, continuous, and clear positive impact to a squad when wielding this ability, and therefore I would put them in situations where they **can not only employ this ability at an expert level but where they set the tone for this at the entire company**

      #{EXAMPLES_BLOCK}
    TEXT
    5 => <<~TEXT.strip,
      I have observed this person showing a consistent, comfortable, continuous, and clear positive impact to **both the entire company, as well as the community/industry in general when wielding this ability -- and they are recognized by the community/industry as an expert**

      #{EXAMPLES_BLOCK}
    TEXT
  }.freeze

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

  private

  def department_must_belong_to_company
    return unless department.present?
    
    if department.company_id != company_id
      errors.add(:department, 'must belong to the same company')
    end
  end
end
