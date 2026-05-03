# frozen_string_literal: true

module AbilitiesHrReview
  # Resolves Assignment#title within an organization: exact → FlexibleNameMatcher → pg_search.
  class AssignmentResolver
    include FlexibleNameMatcher

    def self.call(organization:, title:)
      new(organization: organization, title: title).call
    end

    def initialize(organization:, title:)
      @organization = organization
      @title = title.to_s.strip
    end

    def call
      return empty_result if @title.blank?

      scope = Assignment.where(company_id: @organization.id)

      exact = scope.find_by(title: @title)
      return build_result(exact, 'exact', []) if exact

      flexible = find_with_flexible_matching(Assignment, :title, @title, scope)
      return build_result(flexible, 'flexible', []) if flexible

      search_hits = Assignment.search_by_full_text(@title).where(company_id: @organization.id).limit(5).to_a
      if search_hits.any?
        return build_result(
          search_hits.first,
          'search',
          search_hits.map { |a| { 'id' => a.id, 'title' => a.title } }
        )
      end

      empty_result
    end

    private

    def build_result(assignment, kind, alternatives)
      {
        'assignment_id' => assignment&.id,
        'assignment_title' => assignment&.title,
        'match_kind' => kind,
        'alternatives' => alternatives
      }
    end

    def empty_result
      { 'assignment_id' => nil, 'assignment_title' => nil, 'match_kind' => 'none', 'alternatives' => [] }
    end
  end
end
