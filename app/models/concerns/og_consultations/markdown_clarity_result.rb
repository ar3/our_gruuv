# frozen_string_literal: true

module OgConsultations
  module MarkdownClarityResult
    extend ActiveSupport::Concern

    CLARITY_RATINGS = %w[green yellow red].freeze

    included do
      belongs_to :og_consultation

      validates :clarity_rating, inclusion: { in: CLARITY_RATINGS }, allow_nil: true
    end
  end
end
