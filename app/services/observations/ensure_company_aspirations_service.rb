module Observations
  # Ensures root-company aspirational values are present on an observation.
  # Adds missing Aspiration ratings as na; never removes or resets existing ones.
  class EnsureCompanyAspirationsService
    def initialize(observation:)
      @observation = observation
    end

    def call
      company_aspirations.each do |aspiration|
        next if rating_exists?(aspiration.id)

        add_rating(aspiration)
      end

      @observation
    end

    private

    attr_reader :observation

    def company_aspirations
      company = @observation.company
      root_company = company.respond_to?(:root_company) ? (company.root_company || company) : company
      root_company.aspirations.where(department_id: nil).ordered
    end

    def rating_exists?(aspiration_id)
      if @observation.persisted?
        @observation.observation_ratings.exists?(
          rateable_type: 'Aspiration',
          rateable_id: aspiration_id
        )
      else
        @observation.observation_ratings.any? do |rating|
          rating.rateable_type == 'Aspiration' && rating.rateable_id.to_s == aspiration_id.to_s
        end
      end
    end

    def add_rating(aspiration)
      if @observation.persisted?
        @observation.observation_ratings.create!(
          rateable_type: 'Aspiration',
          rateable_id: aspiration.id,
          rating: 'na'
        )
      else
        rating = @observation.observation_ratings.build(
          rateable_type: 'Aspiration',
          rateable_id: aspiration.id,
          rating: 'na'
        )
        rating.rateable = aspiration
        rating
      end
    end
  end
end
