# frozen_string_literal: true

module AbilitiesHrReview
  # Resolves an imported ability: case-insensitive trimmed name match first (sync).
  # Similarity matching runs later via Llm::AbilitiesHrReviewMatcher in enrichment.
  class AbilityResolver
    def self.call(organization:, name:, description: nil, milestones: nil)
      new(organization: organization, name: name, description: description, milestones: milestones).call
    end

    def initialize(organization:, name:, description: nil, milestones: nil)
      @organization = organization
      @name = name.to_s.strip
      @description = description
      @milestones = milestones
    end

    def call
      return empty_result if @name.blank?

      exact = find_insensitive_exact
      if exact
        candidate = candidate_entry(exact, 100, 'exact_insensitive')
        return {
          'ability_id' => exact.id,
          'canonical_name' => exact.name,
          'match_kind' => 'exact_insensitive',
          'match_candidates' => [candidate]
        }
      end

      empty_result
    end

    private

    def find_insensitive_exact
      normalized = @name.downcase
      Ability.unarchived
             .where(company_id: @organization.id)
             .where('LOWER(TRIM(name)) = ?', normalized)
             .first
    end

    def candidate_entry(ability, confidence, kind)
      {
        'ability_id' => ability.id,
        'name' => ability.name,
        'confidence' => confidence.to_i.clamp(0, 100),
        'match_kind' => kind
      }
    end

    def empty_result
      {
        'ability_id' => nil,
        'canonical_name' => nil,
        'match_kind' => 'none',
        'match_candidates' => []
      }
    end
  end
end
