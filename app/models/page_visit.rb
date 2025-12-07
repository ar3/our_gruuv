class PageVisit < ApplicationRecord
  belongs_to :person

  validates :person, presence: true
  validates :url, presence: true
  validates :visit_count, presence: true, numericality: { greater_than_or_equal_to: 1 }

  scope :recent, -> { order(visited_at: :desc) }
  scope :for_person, ->(person) { where(person: person) }
  scope :most_visited, -> { order(visit_count: :desc, visited_at: :desc) }
  scope :ordered_by_visited_at, -> { order(visited_at: :desc) }
end
