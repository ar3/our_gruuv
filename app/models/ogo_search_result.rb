# frozen_string_literal: true

class OgoSearchResult < ApplicationRecord
  belongs_to :og_consultation

  validates :items_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
