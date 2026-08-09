# frozen_string_literal: true

module Maintainable
  extend ActiveSupport::Concern

  included do
    has_many :object_maintainers, as: :maintainable, dependent: :destroy, inverse_of: :maintainable
    has_many :maintainers, through: :object_maintainers, source: :company_teammate
  end

  def maintained_by?(teammate)
    return false if teammate.blank?

    if object_maintainers.loaded?
      object_maintainers.any? { |membership| membership.company_teammate_id == teammate.id }
    else
      object_maintainers.exists?(company_teammate_id: teammate.id)
    end
  end
end
