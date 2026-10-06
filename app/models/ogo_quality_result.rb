# frozen_string_literal: true

class OgoQualityResult < ApplicationRecord
  belongs_to :og_consultation

  def quality
    (payload || {}).stringify_keys["quality"] || {}
  end

  def proposed_objects
    Array((payload || {}).stringify_keys["proposed_objects"])
  end
end
