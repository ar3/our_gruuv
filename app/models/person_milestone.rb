class PersonMilestone < ApplicationRecord
  # Associations
  belongs_to :person
  belongs_to :ability
  belongs_to :certified_by, class_name: 'Person'

  # Validations
  validates :person, presence: true
  validates :ability, presence: true
  validates :milestone_level, presence: true, 
            numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: 5 }
  validates :certified_by, presence: true
  validates :attained_at, presence: true
  validates :milestone_level, uniqueness: { scope: [:person_id, :ability_id], 
                                          message: 'has already been taken for this person and ability' }

  # Scopes
  scope :by_milestone_level, -> { order(:milestone_level) }
  scope :for_person, ->(person) { where(person: person) }
  scope :for_ability, ->(ability) { where(ability: ability) }
  scope :recent, -> { order(attained_at: :desc) }

  # Instance methods
  def milestone_level_display
    "Milestone #{milestone_level}"
  end

  def attainment_display
    "#{ability.name} - #{milestone_level_display} (attained #{attained_at.strftime('%B %d, %Y')})"
  end

  def certifier_display
    certified_by.display_name
  end
end
