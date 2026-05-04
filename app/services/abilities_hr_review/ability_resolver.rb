# frozen_string_literal: true

module AbilitiesHrReview
  # Resolves an imported ability name to an existing Ability: exact name → FlexibleNameMatcher → pg_search.
  class AbilityResolver
    include FlexibleNameMatcher

    def self.call(organization:, name:)
      new(organization: organization, name: name).call
    end

    def initialize(organization:, name:)
      @organization = organization
      @name = name.to_s.strip
    end

    def call
      return empty_result if @name.blank?

      scope = Ability.where(company_id: @organization.id)

      exact = scope.find_by(name: @name)
      return build_result(exact, 'exact', []) if exact

      flex = find_with_flexible_matching(Ability, :name, @name, scope)
      return build_result(flex, 'flexible', []) if flex

      search_hits = Ability.search_by_full_text(@name).where(company_id: @organization.id).limit(5).to_a
      if search_hits.any?
        alts = search_hits.drop(1).map { |a| { 'id' => a.id, 'name' => a.name } }
        return build_result(search_hits.first, 'search', alts)
      end

      empty_result
    end

    private

    def build_result(ability, kind, alternatives)
      {
        'ability_id' => ability.id,
        'canonical_name' => ability.name,
        'match_kind' => kind,
        'alternatives' => alternatives
      }
    end

    def empty_result
      { 'ability_id' => nil, 'canonical_name' => nil, 'match_kind' => 'none', 'alternatives' => [] }
    end
  end
end
