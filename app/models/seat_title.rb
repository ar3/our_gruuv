class SeatTitle < ApplicationRecord
  belongs_to :seat
  belongs_to :title

  validates :seat_id, uniqueness: { scope: :title_id }
  validate :seat_and_title_in_same_company

  private

  def seat_and_title_in_same_company
    return unless seat&.title && title
    return if seat.title.company_id == title.company_id

    errors.add(:title, 'must belong to the same company as the seat')
  end
end
