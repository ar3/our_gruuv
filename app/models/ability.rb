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
  scope :ordered, -> { order(:name) }
  scope :for_company, ->(company) { where(company_id: company.is_a?(Integer) ? company : company.id) }
  scope :for_department, ->(department) { where(department: department) }
  scope :recent, -> { order(updated_at: :desc) }

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
