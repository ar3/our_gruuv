class Person < ApplicationRecord
  validates :unique_textable_phone_number, uniqueness: true
end
