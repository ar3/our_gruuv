class PageVisit < ApplicationRecord
  belongs_to :person

  validates :person, presence: true
  validates :url, presence: true

  scope :recent, -> { order(visited_at: :desc) }
  scope :for_person, ->(person) { where(person: person) }
  scope :ordered_by_visited_at, -> { order(visited_at: :desc) }
end
