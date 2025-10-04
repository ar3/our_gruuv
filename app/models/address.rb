class Address < ApplicationRecord
  belongs_to :person
  
  validates :address_type, inclusion: { in: %w[home work mailing other] }
  validates :is_primary, uniqueness: { scope: :person_id }, if: :is_primary?
  
  scope :primary, -> { where(is_primary: true) }
  scope :by_type, ->(type) { where(address_type: type) }
end
